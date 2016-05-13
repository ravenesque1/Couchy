[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


Welcome to Couchy!

The idea here is to use Carthage to manage multiple Xcode projects.

To edit Couchy: 

1. Edit Couchy.xcodeproj in the source folder, and commit.
	-ensure that you tag before you push, as Cartfiles work
	with tags. 

2. You can run ./update to update your Cartfile, 
and have those changes reflect in all of your projects:
	-enable permissions if you haven't (chmod +x update.sh)
	-lazy update: $ ./update.sh assumes a remote update
	-choose remote or local: $ ./update.sh <local|remote>
	-choose a tag for your path: $ ./update.sh <local|remote> <tag> 

Good luck!