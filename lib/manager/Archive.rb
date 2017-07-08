require File.dirname(__FILE__) + '/../Config.rb'
require 'json'
require 'zip'

class Archive
  attr_accessor :environment

  def initialize(environment)
    @environment = environment
    Archive.archives[environment.locale] = self
  end

  def archive_path
    Config.archive_path @environment.locale
  end

  def archive_dist_path
    Config.archive_dist_path @environment.locale
  end

  def archive_dist_thumbnail_path
    File.join(archive_dist_path, 'thumbnail/')
  end

  def combine_path(id)
    File.join archive_path, "/#{id}#{Config.mse_output_appendix}"
  end

  def [](id)
    IO.read combine_path id
  end

  def []=(id, value)
    IO.write combine_path(id), value
  end

  def remove(id)
    File.delete combine_path(id)
  end

  def pull
    # 下载
    return unless GitManager.images_raw_repo.pull_latest_release(@environment.locale, Config.archive_dist_pack(@environment.locale))
    # 解压缩
    # https://stackoverflow.com/questions/19754883/how-to-unzip-a-zip-file-containing-folders-and-files-in-rails-while-keeping-the
    ygopro_images_manager_logger.info "Unzipping pack file [#{@environment.locale}] #{archive_path}"
    Zip::File.open(Config.archive_dist_pack(@environment.locale)) do |zip_file|
      zip_file.each do |f|
        f_path = File.join(archive_dist_path, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) { true }
      end
    end
  end

  def push
    GitManager.images_raw_repo.push_latest_release(environment.locale, Config.archive_dist_pack(@environment.locale), '123.zip')
  end

  def state
    ['ok', '']
  end

  def process
    Dir.mkdir archive_dist_path unless Dir.exist? archive_dist_path
    Dir.mkdir archive_dist_thumbnail_path unless Dir.exist? archive_dist_thumbnail_path
    command = "ls -1 #{archive_path} | grep #{Config.mse_output_appendix} | sed -e \"s/\\.png$//\" | xargs -I {} magick \"#{archive_path}{}#{Config.mse_output_appendix}\" \\( +clone -resize 177x254! -write \"#{archive_dist_path}{}.jpg\" +delete \\) -resize 44x64! \"#{archive_dist_thumbnail_path}{}.jpg\""
    ygopro_images_manager_logger.info "Processing command:" + command
    system command
  end

  def pack
    ygopro_images_manager_logger.info "Packing archive [#{@environment.locale}] #{archive_dist_path}"
    Zip::File.open(Config.archive_dist_pack(@environment.locale), Zip::File::CREATE) do |zip_file|
      Dir.glob(archive_dist_path + '*.jpg').each do |file|
        ygopro_images_manager_logger.debug "Archive [#{@environment.locale}] is packing dist #{file}"
        zip_file.add(File.basename(file), file) { true }
      end
      Dir.glob(archive_dist_thumbnail_path + '*.jpg').each do |file|
        ygopro_images_manager_logger.debug "Archive [#{@environment.locale}] is packing dist #{file}"
        zip_file.add('thumbnail/' + File.basename(file), file) { true }
      end
    end
  end
end

class Archive
  class << self
    attr_accessor :archives
    def initialize
      @archives = {}
    end

    def [](locale)
      @archives.key?(locale) ? @archives[locale] : Archive.new(Ygoruby::Environment[locale])
    end
  end
end

Archive.initialize