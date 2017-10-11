module Workers
  class Indexer

    class IndexError < StandardError
    end

    @queue = :index_queue

    class << self

      def defer(object_or_class)
        if object_or_class.is_a? Class
          params = { type: object_or_class.document_type }
          self.perform_async(params)
        elsif object_or_class.id?
          params = {
            id:   object_or_class.id,
            type: object_or_class.class.document_type
          }
          self.perform_async(params)
        end
      rescue Exception => e
        Rails.logger.error "INDEXER: #{e.class} => #{e.message}"
        #raise
      end

      def perform_async(options)
        Resque.enqueue(Workers::Indexer, options)
      end

      def perform(options)
        id, type = options.with_indifferent_access[:id], options.with_indifferent_access[:type]
        id.nil? ? update_class_index(type) : update_instance_index(type, id)
      end

      def update_class_index(type)
        klass = RedmineElasticsearch.type2class(type)
        klass.update_index
      rescue Errno::ECONNREFUSED => e
        raise IndexError, e, e.backtrace
      end

      def update_instance_index(type, id)
        klass    = RedmineElasticsearch.type2class(type)
        document = klass.find id
        document.update_index
      rescue ActiveRecord::RecordNotFound
        klass.remove_from_index id
      rescue Errno::ECONNREFUSED => e
        raise IndexError, e, e.backtrace
      end
    end
  end
end
