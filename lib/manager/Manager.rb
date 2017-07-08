require File.dirname(__FILE__) + '/../ygopro/Compare.rb'
require File.dirname(__FILE__) + '/../ygopro/Fix.rb'

require File.dirname(__FILE__) + '/../mse/MSEHelp.rb'
require File.dirname(__FILE__) + '/../mse/MSEPacker.rb'

require File.dirname(__FILE__) + '/../Config.rb'
require File.dirname(__FILE__) + '/Git.rb'
require File.dirname(__FILE__) + '/Archive.rb'

require 'bundler/setup'
require 'ygoruby-data'
require 'iami-logger'

module YgoproImagesManager
  class << self
    def initialize
      Ygoruby.locale_path = Config.database_path
      Ygoruby.logger = IamI::Logger.new('ygopro_images_manager_logger')
      Ygoruby.logger.stack_count = 3
      Ygoruby.logger.level = :info
    end

    def run_all(locale)
      # 载入卡片
      environment = Ygoruby::Environment[locale]
      environment.load_all_cards
      Ygoruby.fix environment
      # 重做摘要
      current_summary = Ygoruby::Compare.get_summary(environment, Config.images_path)
      current_summary.check_integrity(true)
      current_summary.save Config.summary_path locale
      # 重做所有卡片
      ids = current_summary.environment_summary.keys & current_summary.image_summary.keys
      cards = ids.map { |id| environment[id] }
      process_extra_cards cards, environment
      # 把图片缩小到标准尺寸
      Archive[locale].process
      # 上传图片
      Archive[locale].pack
#      Archive[locale].push
    end

    def run_diff(locale)
      # 载入卡片
      environment = Ygoruby::Environment[locale]
      environment.load_all_cards
      Ygoruby.fix environment
      # 获取摘要
      current_summary = Ygoruby::Compare.get_summary(environment, Config.images_path)
      current_summary.check_integrity(true)
      # 新旧摘要对比
      old_summary = Ygoruby::Compare::Summary.load(Config.summary_path locale)
      extra_ids, removed_ids = Ygoruby::Compare.compare_summary current_summary, old_summary
      if extra_ids.count == 0 and removed_ids.count == 0
        ygopro_images_manager_logger.warn 'Manager doesn\'t detect any database or summary change. Do you hope to regenerate all?'
        return
      end
      # 去掉不存在的
      extra_ids &= current_summary.image_summary.keys
      # 获取添加的卡片，生成卡片
      extra_cards = extra_ids.map { |id| environment[id] }
      process_extra_cards extra_cards, environment
      # 保存摘要
      current_summary.save Config.summary_path locale
      # 获取移除的卡片，删除存档
      process_removed_card removed_ids
      # 把图片缩小到标准尺寸
      Archive[locale].process#(extra_cards, removed_cards)
      # 打包上传图片
      Archive[locale].pack
      # Archive[locale].push
    end

    def run_id(locale, id, formal = false)
      # 载入卡片
      environment = Ygoruby::Environment[locale]
      Ygoruby.fix environment
      card = environment[id]
      if card == nil
        ygopro_images_manager_logger.info "run id return nothing for no that card [#{environment.locale}]/#{id}"
        return nil
      end
      # 生成卡片
      generate_mse_file([card], environment, Config.temp_mse_name)
      output_dir = formal ? Config.archive_path(locale) : (File.dirname(__FILE__) + '/../..' + Config.temp_output_dir)
      output_mse_file File.join(Config.mse_file_path, Config.temp_mse_name), output_dir
      IO.read output_dir + "/#{id}#{Config.mse_output_appendix}"
    end

    def process_extra_cards(cards, environment)
      # 分割卡片
      cards_array = split_cards cards
      # 生成 MSE 文件
      mse_files = cards_array.map.each_with_index {|part_cards, index| generate_mse_file(part_cards, environment, Config.mse_file_name.result(binding))}
      # 将 MSE 文件输出成卡图
      mse_files.each { |mse_file| output_mse_file mse_file, Config.archive_path(environment.locale) }
    end

    def process_removed_card(ids, environment)
      # 获取存档
      archive = Archive[environment.locale]
      ygopro_images_manager_logger.info "Removing #{cards.count} archive image(s) for [#{environment.locale}]"
      # 令存档删除
      ids.each { |id| archive.remove id }
    end

    def split_cards(cards)
      count = (cards.count / (Config.mse_file_card_maximum + 0.0)).ceil
      (0...count).map { |number| cards[(Config.mse_file_card_maximum * number)...(Config.mse_file_card_maximum * (number + 1))] }
    end

    def generate_mse_file(cards, environment, dest)
      # 把 dest 组装成完整路径
      destination = File.join Config.mse_file_path, dest
      # 拼装完整图像路径
      files = cards.map { |card| Config.images_path + '/' + Config.image_file_name.result(binding) }
      # 打包所有文件
      MSEPacker.pack MSEHelp.format_cards(cards, environment), files, destination
      destination
    end

    def output_mse_file(mse_file_path, archive_path)
      mse_path = Config.mse_path + '/mse.exe'
      appendix = Config.mse_output_appendix
      # 生成命令行命令
      command = Config.mse_output_command.result binding
      ygopro_images_manager_logger.info "Output mse project: #{mse_file_path}"
      ygopro_images_manager_logger.debug "Command: #{command}"
      result = `#{command}`
      # 如果结果出错，输出
      ygopro_images_manager_logger.info "Output failed: #{result}" if result != ''
      # 进行改名步骤
      rename_mse_file_generates archive_path
      result
    end

    def rename_mse_file_generates(archive_path)
      ygopro_images_manager_logger.info "Renaming card images under #{archive_path} ..."
      Dir.glob(archive_path + '/*') do |file|
        basename = File.basename(file, '.*')
        id = basename.to_i
        next if id == 0
        File.rename file, File.join(archive_path, id.to_s + File.extname(file))
      end
    end
  end
end

YgoproImagesManager.initialize