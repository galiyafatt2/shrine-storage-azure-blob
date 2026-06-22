# frozen_string_literal: true

require "azure_blob"
require "action_dispatch/http/content_disposition"
require "shrine"
require "stringio"
require_relative "azure_blob/version"

class Shrine
  module Storage
    class AzureBlob
      DEFAULT_URL_TTL = 15 * 60

      attr_reader :client, :container, :prefix

      def initialize(account_name:, container:, access_key: nil, host: nil, prefix: nil, public: false, **options)
        @container = container
        @prefix = prefix
        @public = public
        @client = ::AzureBlob::Client.new(
          account_name: account_name,
          access_key: access_key,
          container: container,
          host: host,
          **options
        )
      end

      def upload(io, id, shrine_metadata: {}, **options)
        client.create_block_blob(
          path_for(id),
          io.respond_to?(:rewind) ? rewindable(io) : io,
          **upload_options(shrine_metadata, options)
        )
      end

      def open(id, **options)
        StringIO.new(fetch_blob(path_for(id), options)).tap(&:binmode)
      rescue ::AzureBlob::Http::FileNotFoundError => error
        raise Shrine::FileNotFound, error.message
      end

      def url(id, expires_in: DEFAULT_URL_TTL, filename: nil, disposition: nil, content_type: nil, public: @public, **)
        return client.generate_uri("#{container}/#{path_for(id)}").to_s if public

        client.signed_uri(
          path_for(id),
          permissions: "r",
          expiry: format_expiry(expires_in),
          content_disposition: content_disposition(disposition, filename),
          content_type: content_type
        ).to_s
      end

      def exists?(id)
        client.blob_exist?(path_for(id))
      end

      def delete(id)
        client.delete_blob(path_for(id))
      rescue ::AzureBlob::Http::FileNotFoundError
        nil
      end

      def delete_prefixed(prefix)
        client.delete_prefix(path_for(prefix))
      end

      def clear!
        delete_prefixed("")
      end

      def presign(id, method: "PUT", expires_in: DEFAULT_URL_TTL, content_type: nil, filename: nil, disposition: nil, metadata: {}, **)
        headers = {
          "x-ms-blob-type" => "BlockBlob"
        }
        headers["Content-Type"] = content_type if present?(content_type)

        custom_metadata_headers(metadata).each do |header, value|
          headers[header.to_s] = value
        end

        if (blob_content_disposition = content_disposition(disposition, filename))
          headers["x-ms-blob-content-disposition"] = blob_content_disposition
        end

        {
          method: method,
          url: client.signed_uri(path_for(id), permissions: "cw", expiry: format_expiry(expires_in)).to_s,
          headers: headers
        }
      end

      def ensure_container!
        return if client.container_exist?

        client.create_container
      end

      private

      def path_for(id)
        [prefix, id].compact.reject { |part| blank?(part) }.join("/")
      end

      def fetch_blob(path, options)
        blob = client.get_blob(path, extract_range_options(options))
        blob.force_encoding(Encoding::BINARY)
      end

      def extract_range_options(options)
        {}.tap do |range_options|
          range_options[:start] = options[:start] if options.key?(:start)
          range_options[:end] = options[:end] if options.key?(:end)
          range_options[:timeout] = options[:timeout] if options.key?(:timeout)
        end
      end

      def rewindable(io)
        io.rewind
        io
      end

      def upload_options(shrine_metadata, options)
        metadata = stringify_metadata(options.fetch(:metadata, {}))
        metadata["filename"] ||= shrine_metadata["filename"] || shrine_metadata[:filename]

        {
          content_type: shrine_metadata["mime_type"] || shrine_metadata[:mime_type],
          metadata: metadata
        }.merge(compact_hash(reject_keys(options, :metadata)))
      end

      def stringify_metadata(metadata)
        compact_hash(metadata.to_h.transform_keys(&:to_s).transform_values(&:to_s))
      end

      def format_expiry(expires_in)
        (Time.now.utc + (expires_in || DEFAULT_URL_TTL)).iso8601
      end

      def content_disposition(disposition, filename)
        return if blank?(disposition) || blank?(filename)

        ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename)
      end

      def custom_metadata_headers(metadata)
        ::AzureBlob::Metadata.new(stringify_metadata(metadata)).headers
      end

      def compact_hash(hash)
        hash.reject { |_, value| value.nil? }
      end

      def reject_keys(hash, *keys)
        hash.reject { |key, _| keys.include?(key) }
      end

      def blank?(value)
        !present?(value)
      end

      def present?(value)
        case value
        when nil then false
        when String then !value.empty?
        else true
        end
      end
    end
  end
end
