//
//  c4Document.h
//  CBForest
//
//  Created by Jens Alfke on 11/6/15.
//  Copyright © 2015 Couchbase. All rights reserved.
//

#ifndef c4Document_h
#define c4Document_h

#include "c4.h"

#ifdef __cplusplus
extern "C" {
#endif


    /** Flags describing a document. */
    typedef C4_OPTIONS(uint32_t, C4DocumentFlags) {
        kDeleted        = 0x01,     /**< The document's current revision is deleted. */
        kConflicted     = 0x02,     /**< The document is in conflict. */
        kHasAttachments = 0x04,     /**< The document's current revision has attachments. */

        kExists         = 0x1000    /**< The document exists (i.e. has revisions.) */
    }; // Note: Superset of VersionedDocument::Flags

    /** Flags that apply to a revision. */
    typedef C4_OPTIONS(uint8_t, C4RevisionFlags) {
        kRevDeleted        = 0x01, /**< Is this revision a deletion/tombstone? */
        kRevLeaf           = 0x02, /**< Is this revision a leaf (no children?) */
        kRevNew            = 0x04, /**< Has this rev been inserted since decoding? */
        kRevHasAttachments = 0x08  /**< Does this rev's body contain attachments? */
    }; // Note: Same as Revision::Flags


    typedef struct {
        C4Slice revID;
        C4RevisionFlags flags;
        C4SequenceNumber sequence;
        C4Slice body;
    } C4Revision;


    /** Describes a version-controlled document. */
    typedef struct C4Document {
        C4DocumentFlags flags;      /**< Document flags */
        C4Slice docID;              /**< Document ID */
        C4Slice revID;              /**< RevID of current revision */
        C4SequenceNumber sequence;  /**< Sequence at which doc was last updated */

        C4Revision selectedRev;
    } C4Document;

    /** Frees a C4Document. */
    void c4doc_free(C4Document *doc);

    /** Gets a document from the database. If there's no such document, the behavior depends on
        the mustExist flag. If it's true, NULL is returned. If it's false, a valid but empty
        C4Document is returned, that doesn't yet exist in the database (but will be added when
        saved.)
        The current revision is selected (if the document exists.) */
    C4Document* c4doc_get(struct c4Database *database,
                          C4Slice docID,
                          bool mustExist,
                          C4Error *outError);

    /** Gets a document from the database given its sequence number. */
    C4Document* c4doc_getBySequence(struct c4Database *database,
                                    C4SequenceNumber,
                                    C4Error *outError);

    /** Returns the document type (as set by setDocType.) This value is ignored by CBForest itself; by convention Couchbase Lite sets it to the value of the current revision's "type" property, and uses it as an optimization when indexing a view. */
    C4SliceResult c4doc_getType(C4Document *doc);


    //////// REVISIONS:


    /** Selects a specific revision of a document (or no revision, if revID is NULL.) */
    bool c4doc_selectRevision(C4Document* doc,
                              C4Slice revID,
                              bool withBody,
                              C4Error *outError);

    /** Selects the current revision of a document.
        (This is the first revision, in the order they appear in the document.) */
    bool c4doc_selectCurrentRevision(C4Document* doc);

    /** Populates the body field of a doc's selected revision,
        if it was initially loaded without its body. */
    bool c4doc_loadRevisionBody(C4Document* doc,
                                C4Error *outError);

    /** Returns true if the body of the selected revision is available,
        i.e. if c4doc_loadRevisionBody() would succeed. */
    bool c4doc_hasRevisionBody(C4Document* doc);

    /** Selects the parent of the selected revision, if it's known, else returns NULL. */
    bool c4doc_selectParentRevision(C4Document* doc);

    /** Selects the next revision in priority order.
        This can be used to iterate over all revisions, starting from the current revision. */
    bool c4doc_selectNextRevision(C4Document* doc);

    /** Selects the next leaf revision; like selectNextRevision but skips over non-leaves. */
    bool c4doc_selectNextLeafRevision(C4Document* doc,
                                      bool includeDeleted,
                                      bool withBody,
                                      C4Error *outError);


    //////// INSERTING REVISIONS:


    /** Adds a new revision to a document, as a child of the currently selected revision
        (or as a root revision if there is no selected revision.)
        On success, the new revision will be selected.
        Must be called within a transaction. Remember to save the document afterwards.
        @param doc  The document.
        @param revID  The ID of the revision being inserted.
        @param body  The (JSON) body of the revision.
        @param deleted  True if this revision is a deletion (tombstone).
        @param hasAttachments  True if this revision contains an _attachments dictionary.
        @param allowConflict  If false, and the parent is not a leaf, a 409 error is returned.
        @param outError  Error information is stored here.
        @return The number of revisions added (0 or 1), or -1 on error. */
        int32_t c4doc_insertRevision(C4Document *doc,
                                     C4Slice revID,
                                     C4Slice body,
                                     bool deleted,
                                     bool hasAttachments,
                                     bool allowConflict,
                                     C4Error *outError);

    /** Adds a revision to a document, plus its ancestors (given in reverse chronological order.)
        On success, the new revision will be selected.
        Must be called within a transaction. Remember to save the document afterwards.
        @param doc  The document.
        @param body  The (JSON) body of the new revision.
        @param deleted  True if the new revision is a deletion (tombstone).
        @param hasAttachments  True if the new revision contains an _attachments dictionary.
        @param history  The ancestors' revision IDs, starting with the new revision's,
                        in reverse order.
        @param historyCount  The number of items in the history array.
        @param outError  Error information is stored here.
        @return The number of revisions added to the document, or -1 on error. */

        int32_t c4doc_insertRevisionWithHistory(C4Document *doc,
                                                C4Slice body,
                                                bool deleted,
                                                bool hasAttachments,
                                                C4Slice history[],
                                                size_t historyCount,
                                                C4Error *outError);

    /** Removes a branch from a document's history. The revID must correspond to a leaf
        revision; that revision and its ancestors will be removed, except for ancestors that are
        shared with another branch.
        If the document has only one branch (no conflicts), the purge will remove every revision,
        and saving the document will purge it (remove it completely from the database.)
        Must be called within a transaction. Remember to save the document afterwards.
        @param doc  The document.
        @param revID  The ID of the revision to purge.
        @param outError  Error information is stored here.
        @return  The total number of revisions purged (including ancestors), or -1 on error. */
        int32_t c4doc_purgeRevision(C4Document *doc,
                                    C4Slice revID,
                                    C4Error *outError);

    /** Sets a document's docType. (By convention this is the value of the "type" property of the current revision's JSON; this value can be used as optimization when indexing a view.)
        The change will not be persisted until the document is saved. */
    bool c4doc_setType(C4Document *doc, C4Slice docType, C4Error *outError);

    /** Saves changes to a C4Document.
        Must be called within a transaction.
        The revision history will be pruned to the maximum depth given. */
    bool c4doc_save(C4Document *doc,
                    uint32_t maxRevTreeDepth,
                    C4Error *outError);

#ifdef __cplusplus
}
#endif

#endif /* c4Document_h */
