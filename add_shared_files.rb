#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/jackwallner/sober/Sober.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files that need to be in the Shared/Models group
model_files = ['GardenItem.swift']

# Targets that need these files
target_names = ['Sober', 'SoberWatch', 'SoberWidgets']

# Find the Shared/Models group
shared_group = project.main_group.find_subpath('Shared', create: false)
unless shared_group
  puts "ERROR: Could not find Shared group"
  exit 1
end

models_group = shared_group.find_subpath('Models', create: false)
unless models_group
  puts "ERROR: Could not find Shared/Models group"
  exit 1
end

model_files.each do |file|
  existing = models_group.files.find { |f| f.path == file }
  next if existing
  ref = models_group.new_file(file)
  
  target_names.each do |tname|
    target = project.targets.find { |t| t.name == tname }
    if target
      target.source_build_phase.add_file_reference(ref)
      puts "Added #{file} to #{tname}"
    end
  end
end

project.save
puts "All files added successfully!"
