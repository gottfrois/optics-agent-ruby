require 'graphql'

module OpticsAgent
  module Normalization
    module Query
      include GraphQL::Language

      # query is a query string
      def normalize(query_string)
        document = GraphQL.parse(query_string)

        # to store results
        output = ''
        used_fragment_names = []
        current = {}
        visitor = Visitor.new(document)

        stack = []
        Nodes.constants.each do |constant|
          mod = Nodes.const_get(constant)
          next unless mod.is_a? Module

          visitor[mod].enter << -> (_, _) do
            stack.unshift(
              arguments: [],
              directives: [],
              selections: []
            )
          end

          visitor[mod].leave << -> (_, _) { current = stack.shift }
        end

        visitor[Nodes::Argument].leave << -> (node, parent) do
          stack[0][:arguments] << "#{node.name}:#{genericize_type(node.value)}"
        end

        visitor[Nodes::Directive].leave << -> (node, parent) do
          id = "@#{node.name}"
          arguments = current[:arguments]
          unless arguments.empty?
            id << "(#{arguments.sort.join(', ')})"
          end
          stack[0][:directives] << id
        end

        visitor[Nodes::Field].leave << -> (node, parent) do
          id = node.name
          arguments = current[:arguments]
          unless arguments.empty?
            id << "(#{arguments.sort.join(', ')})"
          end
          directives = current[:directives]
          unless directives.empty?
            id << " #{directives.sort.join(' ')}"
          end
          selections = current[:selections]
          unless selections.empty?
            id << ' ' + block(selections)
          end

          stack[0][:selections] << id
        end

        visitor[Nodes::InlineFragment].leave << -> (node, parent) do
          selections = current[:selections]
          stack[0][:selections] << "... on #{node.type.name} #{block(selections)}"
        end

        visitor[Nodes::FragmentSpread].leave << -> (node, parent) do
          used_fragment_names << node.name
          stack[0][:selections] << "...#{node.name}"
        end

        visitor[Nodes::OperationDefinition].leave << -> (node, parent) do
          # no need to walk this, I don't think anything else can have vars
          vars = nil
          unless node.variables.empty?
            variable_strs = node.variables.sort_by(&:name).map do |variable|
              "$#{variable.name}:#{format_argument_type(variable.type)}"
            end
            vars = "(#{variable_strs.join(',')})"
          end

          query_content = block(current[:selections])
          if (node.name || vars || node.operation_type != 'query')
            parts = [node.operation_type]
            parts << "#{node.name}#{vars}" if (node.name || vars)
            parts << query_content
            output << parts.join(' ')
          else
            output << query_content
          end
        end

        visitor[Nodes::FragmentDefinition].leave << -> (node, parent) do
          selections = current[:selections]
          if (used_fragment_names.include?(node.name))
            output << " fragment #{node.name} on #{node.type.name} " \
              + block(selections)
          end
        end

        visitor.visit
        output
      end

      private

      # See https://github.com/apollostack/optics-agent/blob/master/docs/signatures.md
      def sort_value(a)
        type_value = if a[0..3] == '... '
          2
        elsif a[0..2] == '...'
          1
        else
          0
        end

        [type_value, a]
      end

      def block(array)
        if array.empty?
          '{}'
        else
          "{#{array.sort_by{ |x| sort_value(x) }.join(' ')}}"
        end
      end

      def format_argument_type(type)
        case type
        when Nodes::ListType
          "[#{format_argument_type(type.of_type)}]"
        when Nodes::NonNullType
          "#{format_argument_type(type.of_type)}!"
        else
          type.name
        end
      end

      def genericize_type(value)
        case value
        when Nodes::VariableIdentifier
          "$#{value.name}"
        when String
          "\"\""
        when Numeric
          "0"
        when TrueClass, FalseClass
          value.to_s
        when Array
          "[]"
        when Nodes::Enum
          value.name
        when Nodes::InputObject
          "{}"
        end
      end
    end
  end
end
