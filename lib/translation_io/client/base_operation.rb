require 'translation_io/client/base_operation/update_pot_file_step'
require 'translation_io/client/base_operation/save_new_po_files_step'
require 'translation_io/client/base_operation/create_new_mo_files_step'
require 'translation_io/client/base_operation/save_new_yaml_files_step'
require 'translation_io/client/base_operation/save_special_yaml_files_step'
require 'translation_io/client/base_operation/dump_markup_gettext_keys_step'

module TranslationIO
  class Client
    class BaseOperation
      attr_accessor :client, :params

      def initialize(client)
        @client = client
        @params = {}
      end

      private

      def warn_wrong_locales(source_locale, target_locales)
        if target_locales.uniq != target_locales
          duplicate_locale = target_locales.detect { |locale| target_locales.count(locale) > 1 }

          puts
          puts "----------"
          puts "Your `config.target_locales` has a duplicate locale (#{duplicate_locale})."
          puts "Please clean your configuration file and execute this command again."
          puts "----------"
          exit(true)
        end

        if target_locales.include?(source_locale)
          puts
          puts "----------"
          puts "The `config.source_locale` (#{source_locale}) can't be included in the `config.target_locales`."
          puts "If you want to customize your source locale, check this link: https://github.com/translation/rails#custom-languages"
          puts "Please clean your configuration file and execute this command again."
          puts "----------"
          exit(true)
        end

        if target_locales.empty?
          puts
          puts "----------"
          puts "Your `config.target_locales` is empty."
          puts "Please clean your configuration file and execute this command again."
          puts "----------"
          exit(true)
        end
      end

      def self.perform_request(uri, params)
        begin
          params.merge!({
            'client'             => 'rails',
            'version'            => TranslationIO.version,
            'source_language'    => TranslationIO.config.source_locale.to_s,
            'target_languages[]' => TranslationIO.config.target_locales.map(&:to_s)
          })

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.read_timeout = 20 * 60 # 20 minutes

          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data(params)

          response        = http.request(request)
          parsed_response = JSON.parse(response.body)

          if response.code.to_i == 200
            return parsed_response
          elsif response.code.to_i == 400 && parsed_response.has_key?('error')
            $stderr.puts "[Error] #{parsed_response['error']}"
            exit(false)
          else
            $stderr.puts "[Error] Unknown error from the server: #{response.code}."
            exit(false)
          end
        rescue Errno::ECONNREFUSED
          $stderr.puts "[Error] Server not responding."
          exit(false)
        end
      end

      def cleanup
        FileUtils.rm_rf(File.join('tmp', 'translation'))

        if TranslationIO.config.disable_gettext
          FileUtils.rm_rf(TranslationIO.config.locales_path)
        end
      end
    end
  end
end
