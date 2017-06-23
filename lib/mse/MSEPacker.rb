require 'zip'
Zip.default_compression = Zlib::NO_COMPRESSION

module MSEPacker
  def self.pack(set, files, dest)
    Zip::File.open(dest, Zip::File::CREATE) do |zip_file|
      zip_file.get_output_stream('set') { |file| file.write set }
      ygopro_images_manager_logger.info "MSE is going to pack #{files.count} files to #{dest}..."
      files.each do |file|
        ygopro_images_manager_logger.debug "MSE is packing file #{file}"
        zip_file.add(File.basename(file), file) { true }
      end
    end
  end
end