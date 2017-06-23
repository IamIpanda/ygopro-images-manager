require 'digest/md5'
require 'yaml'

module Ygoruby
  class Card
    def hash_code
      Digest::MD5.hexdigest [@locale, @id, @type, @category, @name, @desc, @origin_level, @race, @attribute, @atk, @def].join(',')
    end
  end
end

module Ygoruby
  module Compare
    class Summary
      attr_accessor :name
      attr_accessor :environment
      attr_accessor :environment_summary
      attr_accessor :image_summary

      def initialize(name)
        @name = name
        @environment_summary = {}
        @image_summary = {}
        @environment = nil
      end

      def check_integrity(correct = false)
        ygopro_images_manager_logger.info "Checking summary [#{name}] integrity..."
        environment_ids = @environment_summary.keys
        image_ids = @image_summary.keys

        extra_environment_ids = environment_ids - image_ids
        extra_image_ids = image_ids - environment_ids

        if extra_environment_ids.count == 0 and extra_image_ids.count == 0
          ygopro_images_manager_logger.info "Summary [#{name}] integrity check passed."
          return []
        end

        ygopro_images_manager_logger.info "In summary [#{name}], lack #{extra_environment_ids.count} images."
        extra_environment_ids.each { |id| ygopro_images_manager_logger.info @environment[id].to_s }

        ygopro_images_manager_logger.info "In summary [#{name}], lack #{extra_image_ids.count} card database info."
        extra_image_ids.each { |id| ygopro_images_manager_logger.info "[#{id}]" }

        if correct
          ygopro_images_manager_logger.info "Summary [#{name}] is corrected. Above ids are removed."
          extra_environment_ids.each { |id| environment_ids.delete id }
          extra_image_ids.each { |id| image_ids.delete id }
        end

        [extra_environment_ids, extra_image_ids]
      end

      def save(file_path)
        File.open(file_path, 'w') do |file|
          file.write({name:@name, locale: @environment.locale, environment: @environment_summary, image: @image_summary}.to_yaml)
        end
      end

      def self.load(file_path)
        if File.exist? file_path
          data = YAML.load_file file_path
          summary = Summary.new File.basename file_path
          summary.environment = Ygoruby::Environment[data[:locale]]
          summary.environment_summary = data[:environment]
          summary.image_summary = data[:image]
          return summary
        else
          ygopro_images_manager_logger.info "No file #{file_path} for load summary. Will return a 'none' to compare."
          return Summary.new('none')
        end
      end
    end

    class << self
      def get_summary(environment, image_folder)
        summary = Summary.new 'current ' + environment.locale
        environment.cards.values.each {|card| summary.environment_summary[card.id] = card.hash_code}
        files = Dir.glob(image_folder + '/*.*')
        ygopro_images_manager_logger.info "It is going to summary #{files.count} files under #{image_folder}, could take a while..."
        files.each do |file|
          id = File.basename(file, '.*').to_i
          next if id == 0
          summary.image_summary[id] = file_summary(file)
        end
        summary.environment = environment
        summary
      end

      def file_summary(file)
        Digest::MD5.hexdigest(File.open(file) {|f| f.read})
      end

      def compare_summary(current_summary, old_summary)
        ygopro_images_manager_logger.info "Summary compare between [#{current_summary.name}] and [#{old_summary.name}]:"
        changed_card, removed_card = compare_summary_environment current_summary, old_summary
        changed_image, removed_image = compare_summary_image current_summary, old_summary
        [changed_card + changed_image, removed_card]
      end

      def compare_summary_environment(current_summary, old_summary)
        current_extra, old_extra, common_changed = compare_summary_part current_summary.environment_summary, old_summary.environment_summary
        ygopro_images_manager_logger.info 'Database Change:'
        ygopro_images_manager_logger.info "#{current_extra.count} card(s) were added to the database."
        current_extra.each { |id| ygopro_images_manager_logger.debug '[Added] ' + current_summary.environment[id].to_s }
        ygopro_images_manager_logger.info "#{old_extra.count} card(s) were removed from database."
        current_extra.each { |id| ygopro_images_manager_logger.debug '[Removed] ' + id.to_s }
        ygopro_images_manager_logger.info "#{common_changed.count} card(s) changed its data."
        common_changed.each { |id| ygopro_images_manager_logger.debug '[Changed]' + current_summary.environment[id].to_s }
        [current_extra + common_changed, old_extra]
      end

      def compare_summary_image(current_summary, old_summary)
        current_extra, old_extra, common_changed = compare_summary_part current_summary.environment_summary, old_summary.environment_summary
        ygopro_images_manager_logger.info 'Image Change:'
        ygopro_images_manager_logger.info "#{current_extra.count} image(s) were added to the database."
        current_extra.each { |id| ygopro_images_manager_logger.debug '[Added] ' + current_summary.environment[id].to_s }
        ygopro_images_manager_logger.info "#{old_extra.count} image(s) were removed from database."
        current_extra.each { |id| ygopro_images_manager_logger.debug '[Removed] ' + id.to_s }
        ygopro_images_manager_logger.info "#{common_changed.count} image(s) changed."
        common_changed.each { |id| ygopro_images_manager_logger.debug '[Changed]' + current_summary.environment[id].to_s }
        [current_extra + common_changed, old_summary]
      end

      def compare_summary_part(current_summary_part, old_summary_part)
        # 分开三个部分
        current_extra_summary_part = current_summary_part.keys - old_summary_part.keys
        old_extra_summary_part = old_summary_part.keys - current_summary_part.keys
        common_summaries =  current_summary_part.keys - current_extra_summary_part
        common_changed_summaries_part = common_summaries.select { |key| current_summary_part[key] != old_summary_part[key] }
        [current_extra_summary_part, old_extra_summary_part, common_changed_summaries_part]
      end
    end
  end
end