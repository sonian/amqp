class String
  def unindent
    find_indent = proc{ |l| l.find{|l| !l.strip.empty?}.to_s[/^(\s+)/, 1] }

    lines = self.split("\n")
    space = find_indent[lines]
    space = find_indent[lines.reverse] unless space

    strip.gsub(/^#{space}/, '')
  end
  alias ui unindent
end

require 'rubygems'
require 'json'

s = JSON.parse(File.read('amqp-0.8.json'))

# require 'pp'
# pp(s)
# exit

require 'erb'

puts ERB.new(%q[
  module AMQP
    VERSION_MAJOR = <%= s['major-version'] %>
    VERSION_MINOR = <%= s['minor-version'] %>
    DEFAULT_PORT  = <%= s['port'] %>

    <%- s['constants'].each do |c| -%>
    <%= c['name'].tr('-', '_').upcase.ljust(19) -%> = <%= c['value'] %>
    <%- end -%>

    DOMAINS = {
      <%- s['domains'].select{|d| d.first != d.last }.each do |d| -%>
      :<%= d.first.dump -%> => :<%= d.last %>,
      <%- end -%>
    }

    FIELDS = [
      <%- s['domains'].select{|d| d.first == d.last }.each do |d| -%>
      :<%= d.first -%>,
      <%- end -%>
    ]

    class Class
      class << self
        FIELDS.each do |f|
          class_eval %[
            def #{f} name
              @properties ||= []
              @properties << [ :#{f}, name ] unless @properties.include?([:#{f}, name])
            end
          ]
        end
        attr_reader :properties

        def id()   self::ID end
        def name() self::NAME end
      end

      class Method
        class << self
          FIELDS.each do |f|
            class_eval %[
              def #{f} name
                @arguments ||= []
                @arguments << [ :#{f}, name ] unless @arguments.include?([:#{f}, name])
              end
            ]
          end
          attr_reader :arguments

          def id()   self::ID end
          def name() self::NAME end
        end
      end
      
      def self.Method(id, name)
        @methods ||= {}
        @methods[id] ||= ::Class.new(Method) do
          class_eval %[
            def self.inherited klass
              klass.const_set(:ID, #{id})
              klass.const_set(:NAME, :#{name.to_s.dump})
            end
          ]
        end
      end
    end

    def self.Class(id, name)
      @classes ||= {}
      @classes[id] ||= ::Class.new(Class) do
        class_eval %[
          def self.inherited klass
            klass.const_set(:ID, #{id})
            klass.const_set(:NAME, :#{name.to_s.dump})
          end
        ]
      end
    end

    <%- s['classes'].each do |c| -%>
    class <%= c['name'].capitalize %> < Class(<%= c['id'] %>, :<%= c['name'] %>)
      <%- c['properties'].each do |p| -%>
      <%= p['type'].ljust(10) %> :<%= p['name'].tr('-','_') %>
      <%- end if c['properties'] -%>

      <%- c['methods'].each do |m| -%>
      class <%= m['name'].capitalize.gsub(/-(.)/){ "#{$1.upcase}"} %> < Method(<%= m['id'] %>, :'<%= m['name'] %>')
        <%- m['arguments'].each do |a| -%>
        <%- if a['domain'] -%>
        <%= s['domains'].find{|k,v| k == a['domain']}.last.ljust(10) %> :<%= a['name'].tr('- ','_') %>
        <%- else -%>
        <%= a['type'].ljust(10) %> :<%= a['name'].tr('- ','_') %>
        <%- end -%>
        <%- end if m['arguments'] -%>
      end

      <%- end -%>
    end

    <%- end -%>

  end
].ui, nil, '>-%').result(binding)
