# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end
RuboCop::RakeTask.new

desc "Run all checks (RuboCop + Tests)"
task :check => [:rubocop, :test]

desc "Fix RuboCop offenses automatically"
task :fix do
  sh "bundle exec rubocop --auto-correct-all"
end

desc "Generate documentation"
task :docs do
  sh "bundle exec yard doc"
end

desc "Start console with gem loaded"
task :console do
  require "irb"
  require "notion_forge"
  IRB.start
end

desc "Clean up generated files"
task :clean do
  rm_rf "coverage"
  rm_rf "doc"
  rm_rf "pkg"
  rm_f ".yardoc"
end

desc "Test CLI setup process (dry-run)"
task :setup_test do
  puts "🧪 Testing NotionForge CLI Setup Process"
  puts "=" * 50
  
  commands = [
    ["Version check", "./exe/notion_forge version"],
    ["Help overview", "./exe/notion_forge help"],
    ["Setup help (improved)", "./exe/notion_forge help setup"],
    ["Current status", "./exe/notion_forge status"],
    ["Validate demo workspace", "./exe/notion_forge validate demo_workspace.rb"],
    ["Visualize demo workspace", "./exe/notion_forge visualize demo_workspace.rb"]
  ]
  
  commands.each do |name, cmd|
    puts "\n📋 #{name}"
    puts "-" * 40
    system("bundle exec #{cmd}")
    puts "✅ Command completed"
  end
  
  puts "\n🎯 Page ID Extraction Test"
  puts "-" * 40
  system("bundle exec ruby test_page_id_extraction.rb")
  
  puts "\n🎯 Setup test completed!"
  puts "💡 To run actual setup: bundle exec ./exe/notion_forge setup"
  puts "💡 Now you can just paste full Notion URLs! 🚀"
end

task :default => :check
