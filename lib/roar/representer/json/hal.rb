module Roar::Representer
  module JSON
    # Including the JSON::HAL module in your representer will render and parse documents
    # following the HAL specification: http://stateless.co/hal_specification.html
    # Links will be embedded using the +_links+ key, nested resources with the +_embedded+ key.
    #
    # Embedded resources can be specified when calling #property or +collection using the
    # :embedded => true option.
    #
    # Example:
    #
    #   module OrderRepresenter
    #     include Roar::Representer::JSON::HAL
    #
    #     property :id
    #     collection :items, :class => Item, :extend => ItemRepresenter, :embedded => true
    #
    #     link :self do
    #       "http://orders/#{id}"
    #     end
    #   end
    #
    # Renders to
    #
    #   "{\"id\":1,\"_embedded\":{\"items\":[{\"value\":\"Beer\",\"_links\":{\"self\":{\"href\":\"http://items/Beer\"}}}]},\"_links\":{\"self\":{\"href\":\"http://orders/1\"}}}"
    module HAL
      def self.included(base)
        base.class_eval do
          include Roar::Representer::JSON
          include Links       # overwrites #links_definition_options.
          extend ClassMethods # overwrites #links_definition_options, again.
          include Resources
        end
      end

      module Resources
        # Write the property to the +_embedded+ hash when it's a resource.
        def compile_fragment(bin, doc)
          return super unless bin.options[:embedded]
          super(bin, doc[:_embedded] ||= {})
        end

        def uncompile_fragment(bin, doc)
          return super unless bin.options[:embedded]
          super(bin, doc["_embedded"] || {})
        end
      end

      module ClassMethods
        def links_definition_options
          super.tap { |options| options[1].merge!({:from => :_links, :extend => lambda{ |bin|


link_arrays = links_definition.collect do |cfg|
  cfg.first[:array] ? cfg.first[:rel].to_s : nil
end.compact

m = Module.new
m.class_eval( %Q{def wurst; #{link_arrays}; end} )

                      [Roar::Representer::JSON::HAL::Links::LinkCollectionRepresenter, m

                      ]}
          }); puts options.inspect


           }
        end
      end

      # Including this module in your representer will render and parse your embedded hyperlinks
      # following the HAL specification: http://stateless.co/hal_specification.html
      #
      #   module SongRepresenter
      #     include Roar::Representer::JSON
      #     include Roar::Representer::JSON::HAL::Links
      #
      #     link :self { "http://self" }
      #   end
      #
      # Renders to
      #
      #   {"links":{"self":{"href":"http://self"}}}
      #
      # Note that the HAL::Links module alone doesn't prepend an underscore to +links+. Use the JSON::HAL module for that.
      module Links
        def self.included(base)
          base.class_eval do
            include Roar::Representer::Feature::Hypermedia
            include InstanceMethods
            extend Links::ClassMethods
          end
        end
        
        module InstanceMethods
          def prepare_link_for(href, options)
            return super(href, options) unless options[:array]  # TODO: remove :array and use special instan
            
            list = href.collect { |opts| Feature::Hypermedia::Hyperlink.new(opts.merge!(:rel => options[:rel])) }
            LinkArray.new(list)
          end
        end
        
        
        require 'representable/json/hash'
        module LinkCollectionRepresenter
          include Representable::JSON::Hash

          values :extend => lambda { |item| item.is_a?(Array) ? LinkArrayRepresenter : Roar::Representer::JSON::HyperlinkRepresenter },
            :class => lambda { |hsh| hsh.is_a?(LinkArray) ? nil : Roar::Representer::Feature::Hypermedia::Hyperlink }

          def to_hash(options)
            super.tap do |hsh|  # TODO: cool: super(:exclude => [:rel]).
              hsh.each { |k,v| v.delete(:rel) }
            end
          end
          

          def from_hash(hash, options={})
            hash.each do |k,v|
              #link_options = find_options_for_rel_in_binding(options[:binding], k)
              
              hash[k] = LinkArray.new(v) if wurst.include?(k.to_s)  # set type for :class polymorphism. this needs access to the Definition instance.
            end
            
            hsh = super(hash) # this is where :class and :extend do the work.

            hsh.each { |k, v| v.rel = k }
          end

          def find_options_for_rel_in_binding(binding, rel) # FIXME: move to LinksDefinition.
            return {} unless binding
            binding.each do |cfg|
              return cfg.first if cfg.first[:rel] == rel.to_sym
            end
          end
        end

        class LinkArray < Array
          def rel
            first.rel
          end

          def rel=(rel)
            each { |lnk| lnk.rel = rel }
          end
        end

        require 'representable/json/collection'
        module LinkArrayRepresenter
          include Representable::JSON::Collection

          items :extend => Roar::Representer::JSON::HyperlinkRepresenter,
            :class => Roar::Representer::Feature::Hypermedia::Hyperlink

          def to_hash(*)
            super.tap do |ary|
              ary.each do |link|
                rel = link.delete(:rel)
              end
            end
          end
        end


        module ClassMethods
          def links_definition_options
            super.tap { |options|

              options[0] = :links
              options[1] = {:class => Feature::Hypermedia::LinkCollection, :extend => LinkCollectionRepresenter, :from => :_links} 
            }

          end

          def links(options, &block)
            options = {:rel => options} if options.is_a?(Symbol)
            options[:array] = true  # FIXME: we need to save this information somewhere.
            link(options, &block)
          end
        end
      end
    end
  end
end
