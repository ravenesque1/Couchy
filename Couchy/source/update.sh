#!/bin/bash

STABLE_VERSION="\"v1.1\""
SRC=""

is_default=false

if [ $# -eq 0 ]; then
	echo "⚠️	Warning: no option given, performing local update."
	SRC="git \"Couchy\" "
	is_default=true
else
	if [ $1 == "remote" ]; then
		echo "ℹ️	Performing remote update."
		SRC="github \"ravenesque1/Couchy/source\" "
	elif [ $1 == "local" ]; then
		echo "ℹ️	Performing local update."
		SRC="git \"Couchy/source\" "
	else
		SRC="git \"Couchy/source\" "
		is_default=true
	fi
fi

if [ ! -z $2 ] && [ "$is_default" == false ]; then
	SRC=$SRC$2
else
	SRC=$SRC$STABLE_VERSION
fi

echo "✅	Cartfile updated."

cd ../core
echo "$SRC" > "../core/Cartfile"
#time sink--comment out below line if DEBUG
carthage update --platform iOS

#update xcodeprojects
cd ../..
/usr/bin/env ruby <<-EORUBY

require 'xcodeproj'

#add the whitelabel you'd like to update here:
uses_couchy_path = 'UsesCouchy/UsesCouchy.xcodeproj'
couchylite_path = 'CouchyLite/CouchyLite.xcodeproj'

uses_couchy = Xcodeproj::Project.open(uses_couchy_path)
couchylite = Xcodeproj::Project.open(couchylite_path)

projects = [uses_couchy, couchylite]

#update each project
projects.each do |project|
	#remove all old framework references

	project.frameworks_group.clear

	maintarget = project.targets.first
	maintarget.frameworks_build_phase.clear

	embed_phase = maintarget.copy_files_build_phases.detect{ |p| p.name == 'Embed Frameworks'}
	embed_phase.clear

	#add each new framework

	Dir.glob('Couchy/core/Carthage/build/iOS/*.framework') do |f|
		name = File.basename f, ".framework"

		#add file to frameworks folder in project
		file = project.frameworks_group.new_file(f)

		#local path good
		file.path = "../Couchy/core/Carthage/Build/iOS/#{name}.framework"
		
		#add to Linked Frameworks & Libs in general 
		#and create/add to FW build phase
		maintarget.frameworks_build_phase.add_file_reference(file)

		#find embed frameworks phase if it exists or create one

		if maintarget.copy_files_build_phases.map{ |p| p.name }.include? 'Embed Frameworks'
			;
		else
			maintarget.new_copy_files_build_phase("Embed Frameworks")
		end

		embed_phase.add_file_reference(file)

		#ensure search paths are correct
		project.build_configurations.each do |configs|
			fwpaths = configs.build_settings.fetch("FRAMEWORK_SEARCH_PATHS") { configs.build_settings["FRAMEWORK_SEARCH_PATHS"] = ["\$(inherited)"]}
			fwpaths = fwpaths | ["\$(SRCROOT)\/..\/Couchy\/core\/Carthage\/build\/iOS"]
			configs.build_settings["FRAMEWORK_SEARCH_PATHS"] = fwpaths
		end
	end

	project.save
end


EORUBY
