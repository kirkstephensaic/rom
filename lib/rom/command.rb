require 'rom/commands/abstract'

module ROM
  # Base command class with factory class-level interface and setup-related logic
  #
  # @private
  class Command < Commands::Abstract
    extend ClassMacros

    include Equalizer.new(:relation, :options)

    defines :relation, :result, :input, :validator, :register_as

    input Hash
    validator proc {}
    result :many

    # Registers Create/Update/Delete descendant classes during the setup phase
    #
    # @api private
    def self.inherited(klass)
      super
      return if klass.superclass == ROM::Command
      ROM.register_command(klass)
    end

    # Return adapter specific sub-class based on the adapter identifier
    #
    # This is a syntax sugar to make things consistent
    #
    # @example
    #   ROM::Commands::Create[:memory]
    #   # => ROM::Memory::Commands::Create
    #
    # @param [Symbol] adapter identifier
    #
    # @return [Class]
    #
    # @api public
    def self.[](adapter)
      adapter_namespace(adapter).const_get(Inflecto.demodulize(name))
    end

    # Return namespaces that contains command subclasses of a specific adapter
    #
    # @param [Symbol] adapter identifier
    #
    # @return [Module]
    #
    # @api private
    def self.adapter_namespace(adapter)
      ROM.adapters.fetch(adapter).const_get(:Commands)
    end

    # Build a command class for a specific relation with options
    #
    # @example
    #   class CreateUser < ROM::Commands::Create[:memory]
    #   end
    #
    #   command = CreateUser.build(rom.relations[:users])
    #
    # @param [Relation] a relation
    # @param [Hash] options
    #
    # @return [Command]
    #
    # @api public
    def self.build(relation, options = {})
      new(relation, self.options.merge(options))
    end

    # Build command registry hash for provided relations
    #
    # @param [RelationRegistry] relations
    # @param [Hash] repositories
    # @param [Array] a list of command subclasses
    #
    # @return [Hash]
    #
    # @api private
    def self.registry(relations, repositories, descendants)
      descendants.each_with_object({}) do |klass, h|
        rel_name = klass.relation

        next unless rel_name

        relation = relations[rel_name]
        name = klass.register_as || klass.default_name

        repository = repositories[relation.class.repository]
        repository.extend_command_class(klass, relation.dataset)

        (h[rel_name] ||= {})[name] = klass.build(relation)
      end
    end

    # Return default name of the command class based on its name
    #
    # During setup phase this is used by defalut as `register_as` option
    #
    # @return [Symbol]
    #
    # @api private
    def self.default_name
      Inflecto.underscore(Inflecto.demodulize(name)).to_sym
    end

    # Return default options based on class macros
    #
    # @return [Hash]
    #
    # @api private
    def self.options
      { input: input, validator: validator, result: result }
    end
  end
end
