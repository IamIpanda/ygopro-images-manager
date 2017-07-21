require 'erb'

module Config
  class << self
    attr_accessor :config
    attr_accessor :basic_path

    attr_accessor :mse_file_card_maximum
    attr_accessor :mse_file_name
    attr_accessor :mse_output_command
    attr_accessor :mse_output_appendix

    attr_accessor :image_file_name

    attr_accessor :temp_mse_name
    attr_accessor :temp_output_dir

    attr_accessor :server_authorization_key

    def initialize
      @config = YAML.load_file File.dirname(__FILE__) + '/Config.yaml'
      @basic_path = File.join File.dirname(__FILE__), '/..'

      @mse_file_card_maximum = @config['mse_file_card_maximum']
      @mse_file_name = ERB.new @config['mse_file_name']
      @mse_output_command = ERB.new @config['mse_output_command']
      @mse_output_appendix = @config['mse_output_appendix']

      @image_file_name = ERB.new @config['image_file_name']

      @temp_mse_name = @config['temp_mse_name']
      @temp_output_dir = @config['temp_output_dir']

      @server_authorization_key = @config['server_authorization_key']
    end

    define_method(:mse_path) { File.join @basic_path, @config['mse_path'] }
    define_method(:mse_file_path) { File.join @basic_path, @config['mse_file_path'] }
    define_method(:database_path) { File.join @basic_path, @config['database_path'] }
    define_method(:archive_path) { |locale| ERB.new(File.join(@basic_path, @config['archive_path'])).result binding }
    define_method(:archive_dist_path) { |locale| ERB.new(File.join(@basic_path, @config['archive_dist_path'])).result binding }
    define_method(:archive_dist_pack) { |locale| ERB.new(File.join(@basic_path, @config['archive_dist_pack'])).result binding }
    define_method(:images_path) { File.join @basic_path, @config['images_path'] }
    define_method(:summary_path) { |locale| ERB.new(File.join(@basic_path, @config['summary_path'])).result binding }
    define_method(:github) { @config['github_user_name'] + ":" + @config['github_user_password'] }

  end
end

Config.initialize