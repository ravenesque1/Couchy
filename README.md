<a href="url"><img src="https://pixabay.com/static/uploads/photo/2013/07/12/13/58/settee-147701_960_720.png" align="center" height="360"></a>


# Couchy [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/ravenesque1/Couchy)

#### Welcome to Couchy!

The idea here is to use Carthage to manage multiple Xcode projects. Yes, I am aware that [Cocoapods](https://cocoapods.org/) exists, but it comes with limitations. Namely, it's very difficult to create a centralized core for your various white-labels if your core is a mixed-language framework.

Couchy is an attempt at solving this problem by using Carthage's tagging and update system along with the [xcodeproj](https://rubygems.org/gems/xcodeproj/versions/0.28.2) ruby gem to build a setup that allows the developer to have a self-contained, editable "Couchy" core that is used by the two sample white-labels, "UsesCouchy" and "CouchyLite".

Why "Couchy"? Well, it uses [CouchbaseLite](http://www.couchbase.com/nosql-databases/downloads?utm_source=MKTG-SEM&utm_medium=g&utm_campaign=316854429&utm_term=%2Bcouchbase&utm_content=&gclid=CNTBg5qM2MwCFYZefgodrg0OfA). Several projects of mine depend on CouchbaseLite; this is fine, as it exists as a cocoapod. However, the cocoapod is written in Objective-C. This itself wouldn't be a problem, but not all headers included are public. This means that if your core is a cocoapod and it also depends on the couchbase cocoapod, then you can't include `.swift` files in your cocoapod if you intend to use it as a dynamic framework. 

So, I've abandoned Cocoapods in favor of using Carthage. You are limited to projects that are Carthage-compatible, which currently seems smaller than the set of projects that are Cocoapods-compatible, but if you too have this problem, it might be worth it to convert to Carthage. Enjoy!
***
To use Couchy: 

**First**, and most importantly, understand that this repository is actually 2 repositories. The aim is to use the `couchy` branch to edit the core, and then github's tags to handle the "Couchy" core source. That's the first 'repository'. The second one takes the form of gitflow (ideally). As a quick overview, you have a `master` branch with stable releases, and a `develop` branch that houses, well, developing changes. To work on a feature, use `feature/myFeature`. Every branch that is a part of gitflow contains all white-labels. 

[_Note: Considering allowing a `couchy/gitflow` to better manage the core._]

**Second**, understand the workflow:
1. Edit Couchy.xcodeproj in the source folder, and commit on a `couchy` branch. Make sure you push the specific tag as well ([See info on tagging in Github](https://git-scm.com/book/en/v2/Git-Basics-Tagging)).

2. Run the update script. 
    1. Make sure permissions are enabled. If you can't run it, try `chmod+x update.sh` in the correct directory.
    2. I run a zsh shell, so the easiest thing for me to do is `sh update.sh` to run the script.
    3. Syntax: `update.sh` <remote|local> <tag>
        * Basic remote update: `sh update.sh` or `sh update.sh remote` (uses `v1.1` tag)
        * Basic local updae: `sh update.sh local` (still uses `v1.1` tag)
        * Specific update: `sh update local v1.4`


3. Use the updates. I currently use `carthage update --platform iOS` as the update command, but this would change if you have multiple platforms (like WatchOS or tvOS). Furthermore, this is a very slow update command, which I'm still looking to optimize.

**Final Note**: This _is_ just a work in progress. The script is likely to work fine, but always be careful running shell scripts. Also, I'm still working out kinds, so as mentioned, carthage updates are very slow. And because FRAMEWORKS are being copied over, git pushes can be slow too. 

Enjoy!