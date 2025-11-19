# frozen_string_literal: true

module NotionForge
  module Property
    extend self

    def build(type, **opts)
      send(type, **opts)
    rescue NoMethodError
      raise ArgumentError, "Unknown property type: #{type}"
    end

    # Define properties with metaprogramming
    {
      title: -> { { title: {} } },
      text: -> { { rich_text: {} } },
      checkbox: -> { { checkbox: {} } },
      url: -> { { url: {} } },
      email: -> { { email: {} } },
      phone: -> { { phone_number: {} } },
      date: -> { { date: {} } },
      files: -> { { files: {} } },
      created_time: -> { { created_time: {} } },
      created_by: -> { { created_by: {} } },
      last_edited_time: -> { { last_edited_time: {} } },
      last_edited_by: -> { { last_edited_by: {} } },
    }.each do |name, builder|
      define_method(name, &builder)
    end

    def number(format: "number")
      { number: { format: format } }
    end

    def select(options: [])
      {
        select: {
          options: normalize_options(options),
        },
      }
    end

    def multi_select(options: [])
      {
        multi_select: {
          options: normalize_options(options),
        },
      }
    end

    def status(options: [])
      {
        status: {
          options: normalize_options(options),
        },
      }
    end

    def relation(database_id:)
      {
        relation: {
          database_id: database_id,
        },
      }
    end

    private

    def normalize_options(opts)
      opts.map do |opt|
        case opt
        in { name:, color: } then opt
        in { name: } then { name: opt[:name], color: "default" }
        in String then { name: opt, color: "default" }
        else { name: opt.to_s, color: "default" }
        end
      end
    end
  end
end
