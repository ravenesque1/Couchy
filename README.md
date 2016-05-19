<a href="url"><img src="https://pixabay.com/static/uploads/photo/2013/07/12/13/58/settee-147701_960_720.png" align="center" height="360"></a>


# Couchy [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/ravenesque1/Couchy)

#### Welcome to Couchy!

The idea here is to use Carthage to manage multiple Xcode projects. Yes, I am aware that [Cocoapods](https://cocoapods.org/) exists, but it comes with limitations. Namely, it's very difficult to create a centralized core for your various white-labels if your core is a mixed-language framework.

Couchy is an attempt at solving this problem by using Carthage's tagging and update system along with the [xcodeproj](https://rubygems.org/gems/xcodeproj/versions/0.28.2) ruby gem to build a setup that allows the developer to have a self-contained, editable "Couchy" core that is used by the two sample white-labels, "UsesCouchy" and "CouchyLite".

Why "Couchy"? Well, it uses [CouchbaseLite](http://www.couchbase.com/nosql-databases/downloads?utm_source=MKTG-SEM&utm_medium=g&utm_campaign=316854429&utm_term=%2Bcouchbase&utm_content=&gclid=CNTBg5qM2MwCFYZefgodrg0OfA). Several projects of mine depend on CouchbaseLite; this is fine, as it exists as a cocoapod. However, the cocoapod is written in Objective-C. This itself wouldn't be a problem, but not all headers included are public. This means that if your core is a cocoapod and it also depends on the couchbase cocoapod, then you can't include `.swift` files in your cocoapod if you intend to use it as a dynamic framework. 

So, I've abandoned Cocoapods in favor of using Carthage. You are limited to projects that are Carthage-compatible, which currently seems smaller than the set of projects that are Cocoapods-compatible, but if you too have this problem, it might be worth it to convert to Carthage.

***
#### Recommended Flow:

I have two repositories on my system. I recommend making a folder for Couchy itself, and a separate folder for the white-labels (mine is called `couchy-suite`). Setting up the folder structure this way facilitates getting the 'feel' for development; I might add a new image to the framework itself, and then go ahead and introduce those changes with `sh update.sh local`.

`UsesCouchy` and `CouchyLite` are included to demonstrate that the dependencies used in Couchy can be used in both swift and objective-c projects.


***
#### In Action:

After setting up Couchy (and perhaps before diving right into development), try out the sample tags I created! `v1.1` introduces a `CouchyController` that is set as the root for the white-labels. Run both projects and smile when the build succeeds in both an Objective-C and Swift project! Then, you can update to `v1.2` to see the `CouchyController` get a much needed facelift. I've provided this as visual proof, but you can also see that the white-labels successfully compile a mix of objects--couchbaselite items, a swift `ParentContainer` class, and some objective-c `ChildModels`. So while updating Couchy itself is a timesink, development on the white-labels doesn't have to be **nearly** as painful.

***
#### To use Couchy: 

**First**, and most importantly, understand that this repository is actually 2 repositories. The aim is to use the `couchy` branch to edit the core, and then github's tags to handle the "Couchy" core source. That's the first 'repository'. The second one takes the form of gitflow (ideally). As a quick overview, you have a `master` branch with stable releases, and a `develop` branch that houses, well, developing changes. To work on a feature, use `feature/myFeature`. Every branch that is a part of gitflow contains all white-labels. 

[_Note: Considering allowing a `couchy/gitflow` to better manage the core._]

**Second**, understand the workflow:

1. Edit Couchy.xcodeproj in the source folder, and commit on a `couchy` branch. Make sure you push the specific tag as well ([See info on tagging in Github](https://git-scm.com/book/en/v2/Git-Basics-Tagging)).

2. Run the update script. 
    1. Make sure permissions are enabled. If you can't run it, try `chmod+x update.sh` in the correct directory.
    2. I run a zsh shell, so the easiest thing for me to do is `sh update.sh` to run the script.
    3. Syntax: `update.sh` <remote|local> <tag>
        * Basic local update: `sh update.sh` or `sh update.sh local` (uses `v1.1` tag)
        * Basic remote updae: `sh update.sh remote` (still uses `v1.1` tag)
        * Specific update: `sh update local v1.4`


3. Use the updates. I currently use `carthage update Couchy --platform iOS` as the update command, but this would change if you have multiple platforms (like WatchOS or tvOS). 

[_Note: Need to add functionality in update script to include multiple targets._]

If you visit commits [b0499daa](https://github.com/ravenesque1/Couchy/commit/b049daadf762932d87e3018de5d6974e9601b166) and [0705c85](https://github.com/ravenesque1/Couchy/commit/0705c85db882e524e70250210ac4aa4af28c4c5b), you can see an example of starting switching Couchy versions. The only action taken in these two commits were `sh update.sh remote` and `sh update.sh remote v1.2`, respectively.

***
#### Warnings and Known Issues: 
1. **It's really slow**. I currently want to be able to just build Couchy without updating the dependencies, but I haven't figured out a way to do so. This means that right now, if you're doing framework dev alongside app creation, you can get stuck waiting for 5+ minutes just trying to integrate framework changes. 

2. This has more to do with Carthage, so those already familiar can skip this part. Carthage expects [semantic versioning](https://gist.github.com/jashkenas/cbd2b088e20279ae2c8e), which means you version your projects like so: `a.b.c` where `a` is a major relase, `b` is a minor one, and `c` is a patch. Furthermore, your version can't have letters in it like this: `1.2.alpha-1`. So if your project doesn't follow this scheme, it's time to conform.

3. _Another Carthage-specific issue_: Because Carthage uses the tagging system, take time to refresh yourself on git's method of [tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging). Tags point to commits, so when you force-push to overwite one or several commits, things can get hairy. I personally like to overwrite my tags sometimes (not the best practice, mind you), so I've included a line in `upd.sh` that clears the cache and enables Carthage to update an overwritten tag. I don't think just clearing the cache on update is necessarily, hence the warning/issue. 

***
⚠️ **Final Note**: This _is_ just a work in progress. The script is likely to work fine, but always be careful running shell scripts. Also, I'm still working out kinks, so as mentioned, carthage updates are very slow. And because FRAMEWORKS are being copied over, git pushes can be slow too. 

Enjoy!