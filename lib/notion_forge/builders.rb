# frozen_string_literal: true

using NotionForge::Refinements

module NotionForge
  class DatabaseBuilder
    def initialize(database)
      @database = database
    end

    def prop(...) = @database.prop(...)
    def relate(...) = @database.relate(...)

    alias_method :property, :prop
    alias_method :relation, :relate

    # Explicit method definitions for conflicting Ruby built-ins
    def select(name = "Select", options: [])
      prop(name, :select, options: options)
    end

    def status(name = "Status", options: [])
      prop(name, :status, options: options)
    end

    def title(name = "Title")
      prop(name, :title)
    end

    def text(name = "Text")
      prop(name, :text)
    end

    def date(name = "Date")
      prop(name, :date)
    end

    def url(name = "URL")
      prop(name, :url)
    end

    def number(name = "Number", format: "number")
      prop(name, :number, format: format)
    end

    def checkbox(name = "Checkbox")
      prop(name, :checkbox)
    end

    def email(name = "Email")
      prop(name, :email)
    end

    def phone(name = "Phone")
      prop(name, :phone)
    end

    def multi_select(name = "Multi-select", options: [])
      prop(name, :multi_select, options: options)
    end

    def created_time(name = "Created time")
      prop(name, :created_time)
    end

    def created_by(name = "Created by")
      prop(name, :created_by)
    end

    def last_edited_time(name = "Last edited time")
      prop(name, :last_edited_time)
    end

    def last_edited_by(name = "Last edited by")
      prop(name, :last_edited_by)
    end

    def files(name = "Files")
      prop(name, :files)
    end

    def template(title, icon: nil, props: {}, &block)
      tmpl = @database.template(title, icon: icon, props: props, &block)
      
      # Make template dependent on database so it's created after the database
      tmpl.depends_on(@database)
      
      # Register template with workspace so it gets processed in dependency order
      workspace = @database.instance_variable_get(:@workspace)
      workspace&.add_resource(tmpl)
      
      tmpl
      
      tmpl
    end

    # Magic method_missing for any other property types
    def method_missing(method, *args, **kwargs, &block)
      if Property.respond_to?(method, true)
        name = args.first || method.to_s.capitalize
        prop(name, method, **kwargs)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      Property.respond_to?(method, true) || super
    end
  end

  class PageBuilder
    def initialize(page)
      @page = page
    end

    # Delegate all Block methods
    Block.public_methods(false).each do |method|
      define_method(method) do |*args, **kwargs, &block|
        @page.children << Block.send(method, *args, **kwargs, &block)
      end
    end

    # DSL macro: Create section with header and content
    def section(title, level: 2, &block)
      @page.children << Block.heading(level, title)
      instance_eval(&block) if block
      @page.children << Block.divider
    end

    # DSL macro: Create expandable section
    def expandable(title, &block)
      content = if block
        builder = PageBuilder.new(Page.new(title: "", parent_id: ""))
        builder.instance_eval(&block)
        builder.instance_variable_get(:@page).children
      else
        []
      end

      @page.children << Block.toggle(title, content)
    end

    def raw(block)
      @page.children << block
    end
  end
end
