//
//  MapReduce_Test.m
//  CBForest
//
//  Created by Jens Alfke on 5/27/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "testutil.h"
#import "MapReduceIndex.hh"
#import "Collatable.hh"

using namespace cbforest;

static NSData* JSONToData(id obj, NSError** outError) {
    return [NSJSONSerialization dataWithJSONObject: obj options: 0 error: outError];
}

static inline id DataToJSON(NSData* data, NSError** outError) {
    return [NSJSONSerialization JSONObjectWithData: data
                                           options: NSJSONReadingAllowFragments
                                             error: NULL];
}

static Collatable StringToCollatable(NSString* str) {
    Collatable c;
    c << str;
    return c;
}


class TestJSONMappable : public Mappable {
public:
    TestJSONMappable(const Document& doc)
    :Mappable(doc)
    {
        if (doc.deleted())
            body = nil;
        else
            body = DataToJSON(doc.body().copiedNSData(), NULL);
    }
    __strong NSDictionary* body;
};

class TestMapFn : public MapFn {
public:
    static int numMapCalls;
    virtual void operator() (const Mappable& mappable, EmitFn& emit) {
        ++numMapCalls;
        NSDictionary* body = ((TestJSONMappable&)mappable).body;
        if (body) {
            for (NSString* city in body[@"cities"])
                emit(StringToCollatable(city), StringToCollatable(body[@"name"]));
        }
    }
};

int TestMapFn::numMapCalls;

class TestIndexer : public MapReduceIndexer {
public:
    static bool updateIndex(Database* database, MapReduceIndex* index) {
        TestIndexer indexer;
        indexer.addIndex(index, new Transaction(database));
        return indexer.run();
    }

    virtual void addDocument(const Document& doc) {
        TestJSONMappable mappable(doc);
        addMappable(mappable);
    }
};


@interface MapReduce_Test : XCTestCase
@end

@implementation MapReduce_Test
{
    std::string dbPath;
    Database* db;
    KeyStore source;
    MapReduceIndex* index;
}

+ (void) initialize {
    if (self == [MapReduce_Test class]) {
        LogLevel = kWarning;
    }
}

- (void) setUp {
    [super setUp];
    CreateTestDir();
    dbPath = PathForDatabaseNamed(@"forest_temp.fdb");
    db = new Database(dbPath, TestDBConfig());
    source = (KeyStore)*db;
    index = new MapReduceIndex(db, "index", source);
    Assert(index, @"Couldn't open index");
}

- (void)tearDown
{
    delete index;
    delete db;
    [super tearDown];
}


- (void) queryExpectingKeys: (NSArray*)expectedKeys {
    TestMapFn::numMapCalls = 0;
    XCTAssertTrue(TestIndexer::updateIndex(db, index));

    unsigned nRows = 0;
    for (IndexEnumerator e(index, Collatable(), cbforest::slice::null,
                           Collatable(), cbforest::slice::null,
                           DocEnumerator::Options::kDefault); e.next(); ) {
        CollatableReader keyReader(e.key());
        alloc_slice keyStr = keyReader.readString();
        NSString* key = (NSString*)keyStr;
        NSLog(@"key = %@, docID = %.*s",
              key, (int)e.docID().size, e.docID().buf);
        AssertEqual(key, expectedKeys[nRows++]);
    }
    XCTAssertEqual(nRows, expectedKeys.count);
    XCTAssertEqual(index->rowCount(), nRows);
}


- (void) createDocsAndIndex {
    {
        // Populate the database:
        NSDictionary* data = @{
               @"CA": @{@"name": @"California",
                        @"cities":@[@"San Jose", @"San Francisco", @"Cambria"]},
               @"WA": @{@"name": @"Washington",
                        @"cities": @[@"Seattle", @"Port Townsend", @"Skookumchuk"]},
               @"OR": @{@"name": @"Oregon",
                        @"cities": @[@"Portland", @"Eugene"]}};
        Transaction trans(db);
        for (NSString* docID in data) {
            trans.set(nsstring_slice(docID), cbforest::slice::null, JSONToData(data[docID],NULL));
        }
    }

    {
        Transaction trans(db);
        index->setup(trans, 0, new TestMapFn, "1");
    }
}


- (void) testMapReduce {
    [self createDocsAndIndex];

    NSLog(@"--- First query");
    [self queryExpectingKeys: @[@"Cambria", @"Eugene", @"Port Townsend", @"Portland",
                                @"San Francisco", @"San Jose", @"Seattle", @"Skookumchuk"]];
    AssertEq(TestMapFn::numMapCalls, 3);

    NSLog(@"--- Updating OR");
    {
        Transaction trans(db);
        NSDictionary* body = @{@"name": @"Oregon",
                               @"cities": @[@"Portland", @"Walla Walla", @"Salem"]};
        trans.set(nsstring_slice(@"OR"), cbforest::slice::null, JSONToData(body,NULL));
    }
    [self queryExpectingKeys: @[@"Cambria", @"Port Townsend", @"Portland", @"Salem",
                                @"San Francisco", @"San Jose", @"Seattle", @"Skookumchuk",
                                @"Walla Walla"]];
    AssertEq(TestMapFn::numMapCalls, 1);

    NSLog(@"--- Deleting CA");
    {
        Transaction trans(db);
        trans.del(nsstring_slice(@"CA"));
    }
    [self queryExpectingKeys: @[@"Port Townsend", @"Portland", @"Salem",
                                @"Seattle", @"Skookumchuk", @"Walla Walla"]];
    AssertEq(TestMapFn::numMapCalls, 0);

    NSLog(@"--- Updating version");
    {
        Transaction trans(db);
        index->setup(trans, 0, new TestMapFn, "2");
    }
    [self queryExpectingKeys: @[@"Port Townsend", @"Portland", @"Salem",
                                @"Seattle", @"Skookumchuk", @"Walla Walla"]];
    AssertEq(TestMapFn::numMapCalls, 2);
}

- (void) testReopen {
    [self createDocsAndIndex];
    XCTAssertTrue(TestIndexer::updateIndex(db, index));
    sequence lastIndexed = index->lastSequenceIndexed();
    sequence lastChangedAt = index->lastSequenceChangedAt();
    Assert(lastChangedAt > 0);
    Assert(lastIndexed >= lastChangedAt);

    delete index;
    index = NULL;

    index = new MapReduceIndex(db, "index", source);
    Assert(index, @"Couldn't reopen index");

    {
        Transaction trans(db);
        index->setup(trans, 0, new TestMapFn, "1");
    }
    AssertEq(index->lastSequenceIndexed(), lastIndexed);
    AssertEq(index->lastSequenceChangedAt(), lastChangedAt);
}

@end
