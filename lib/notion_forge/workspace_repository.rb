# frozen_string_literal: true

require "fileutils"
require "pathname"

module NotionForge
  class WorkspaceRepository
    WORKSPACE_DIR = File.join(File.expand_path("~/.notion_forge"), "workspaces")
    BUILTIN_WORKSPACES_DIR = File.expand_path("../../../", __FILE__)

    def initialize
      ensure_workspace_directory
    end

    # List all available workspaces (built-in + custom)
    def list_workspaces
      workspaces = []
      
      # Add built-in workspaces from the gem directory
      builtin_files = Dir.glob(File.join(BUILTIN_WORKSPACES_DIR, "*workspace*.rb"))
      builtin_files.each do |file|
        name = File.basename(file, ".rb")
        workspaces << {
          name: name,
          file: file,
          builtin: true,
          type: :builtin
        }
      end
      
      # Add custom workspaces from user directory
      custom_files = Dir.glob(File.join(WORKSPACE_DIR, "*.rb"))
      custom_files.each do |file|
        name = File.basename(file, ".rb")
        workspaces << {
          name: name,
          file: file,
          builtin: false,
          type: :custom
        }
      end
      
      workspaces.sort_by { |w| [w[:builtin] ? 0 : 1, w[:name]] }
    end

    # Find a workspace by name (checks both built-in and custom)
    def find_workspace(name)
      # Remove .rb extension if provided
      name = name.sub(/\.rb$/, '')
      
      # Check custom workspaces first
      custom_path = File.join(WORKSPACE_DIR, "#{name}.rb")
      return custom_path if File.exist?(custom_path)
      
      # Check built-in workspaces
      builtin_path = File.join(BUILTIN_WORKSPACES_DIR, "#{name}.rb")
      return builtin_path if File.exist?(builtin_path)
      
      # Check current directory as fallback
      local_path = File.join(Dir.pwd, "#{name}.rb")
      return local_path if File.exist?(local_path)
      
      nil
    end

    # Install a workspace template to user directory
    def install_workspace(source_file, name = nil)
      name ||= File.basename(source_file, ".rb")
      destination = File.join(WORKSPACE_DIR, "#{name}.rb")
      
      if File.exist?(destination)
        raise "Workspace '#{name}' already exists. Use --force to overwrite."
      end
      
      FileUtils.cp(source_file, destination)
      destination
    end

    # Copy built-in workspace to user directory for customization
    def copy_builtin_workspace(name, new_name = nil)
      builtin_path = File.join(BUILTIN_WORKSPACES_DIR, "#{name}.rb")
      unless File.exist?(builtin_path)
        raise "Built-in workspace '#{name}' not found"
      end
      
      new_name ||= "custom_#{name}"
      destination = File.join(WORKSPACE_DIR, "#{new_name}.rb")
      
      if File.exist?(destination)
        raise "Workspace '#{new_name}' already exists"
      end
      
      FileUtils.cp(builtin_path, destination)
      destination
    end

    # Preview workspace information without loading it fully
    def preview_workspace(file_path)
      return nil unless File.exist?(file_path)
      
      content = File.read(file_path)
      
      # Extract basic information using simple parsing
      info = {
        title: extract_title(content),
        databases: count_databases(content),
        pages: count_pages(content)
      }
      
      info
    rescue
      nil
    end

    # Remove a custom workspace
    def remove_workspace(name)
      path = File.join(WORKSPACE_DIR, "#{name}.rb")
      
      unless File.exist?(path)
        raise "Workspace '#{name}' not found in custom workspaces"
      end
      
      File.delete(path)
    end

    # List workspace files in current directory (legacy support)
    def find_local_workspaces
      candidates = Dir.glob("*workspace*.rb") + Dir.glob("*_workspace.rb") + Dir.glob("workspace*.rb")
      candidates.first
    end

    private

    def ensure_workspace_directory
      return if Dir.exist?(WORKSPACE_DIR)
      
      begin
        FileUtils.mkdir_p(WORKSPACE_DIR)
      rescue Errno::EEXIST
        # Directory already exists, which is fine
      end
    end

    def extract_title(content)
      # Look for title in workspace definition
      if match = content.match(/title:\s*["']([^"']+)["']/)
        return match[1]
      end
      
      if match = content.match(/NotionForge::Workspace\.new\([^)]*["']([^"']+)["']/)
        return match[1]
      end
      
      "Unknown Workspace"
    end

    def count_databases(content)
      # Count database definitions
      content.scan(/database\s+["']/).size
    end

    def count_pages(content)
      # Count page definitions
      content.scan(/page\s+["']/).size
    end
  end
end
