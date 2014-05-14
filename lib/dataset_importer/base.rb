module DatasetImporter
  class Base < OpenStruct
    #This class/methods are run in console or rack tasks, hence the puts statements.
    #downloads fastest w/ aria2 installed.   `sudo apt-get install aria2`

    # importer = DatasetImporter.new(:year => 2013)
    # importer.download_census!

    DOWNLOAD_COMMAND_OPTIONS = {
      :wget => '-nc -c  --directory-prefix=',
      :aria2c => '-c -d '
    }

    TEMPORARY_PREPRODUCTION_TABLE = 'pending_districts'
    PRODUCTION_TABLE = 'districts'

    def self.import_and_process!(options={})
      all_importers.each{|importer| importer.import_and_process!(options)}
    end

    def self.download_all!(options={})
      all_importers.each{|importer| importer.download!}
    end

    def self.all_importers
      [
        DatasetImporter::Census.new(:year => '2011'),
        DatasetImporter::Census.new(:year => '2013'),
        # DatasetImporter::Ak.new, #GIS file not importable
        DatasetImporter::Ky.new,
        # DatasetImporter::Me.new, #GIS file not importable
        DatasetImporter::Mt.new,
        DatasetImporter::Pa.new,
        DatasetImporter::Tx.new
      ]
    end

    def initialize(new_attributes={})
      super(new_attributes)
      self.connection = ActiveRecord::Base.connection
      self.database_config = self.connection.instance_variable_get(:@config) #{:adapter=>"postgresql", :database=>"congress_development", :username=>"postgres", :password=>nil, :host=>"127.0.0.1"}
      self.origin = Dataset.where(:source_identifer => dataset_attributes[:source_identifer].downcase).first
      self.epsg_code = self.origin.try(:epsg_code)
      puts 'initialized!'
    end

    def download!; raise 'implement in subclass'; end

    def unzip!
      self.create_path_and_clean!(shape_files_directory,true)
      p "Unzipping relevant files to #{shape_files_directory}"

      unzip_options = "*.SHP *.DBF *.SHX *.PRJ *.prj *.shp *.dbf *.shx -d #{shape_files_directory}/"  #extracts all files w/ relevant extensions
      puts "You can IGNORE unmatched files"
      Dir.glob("#{zip_files_directory}/*") do |zip_file|
        `unzip #{zip_file} #{unzip_options}`
      end
    end

    def import_shapefiles!; raise 'implement in subclass'; end

    def store_dataset_origin!(options={})
      self.origin ||= self.class.store_dataset_origin!(dataset_attributes(options.merge(:epsg_code => self.epsg_code)))
      unless self.origin.epsg_code.present?
        fetch_epsg_encoding!
        self.origin.update_attributes!(:epsg_code => self.epsg_code)
      end
    end

    def self.store_dataset_origin!(attributes_to_store)
      table_name = attributes_to_store.delete(:table_name)
      Dataset.create!(attributes_to_store)
    end

    # congress.mcommons.com may contain data imported from interim (census113_interm) data. This method saves as a new dataset.
    # 2013 data is better. Better to just replace it.
    def self.update_legacy_data!
      fake_instance = DatasetImporter::Census.new(:year => 2010)
      options = fake_instance.dataset_attributes(
        :congressional_session => '113',
        :tab_id => '113',
        :table_name => PRODUCTION_TABLE,
        :source_identifer => 'census113_interm',
      )
      ActiveRecord::Base.transaction do
        add_column(options[:table_name],:dataset_id,:integer)
        ActiveRecord::Base.connection.execute("ALTER TABLE #{options[:table_name]} ADD geom2d geometry; UPDATE #{options[:table_name]} SET geom2d = ST_Force_2D(the_geom) ")
        ActiveRecord::Base.connection.execute("ALTER TABLE #{options[:table_name]} DROP COLUMN the_geom; ALTER TABLE #{options[:table_name]} RENAME COLUMN geom2d TO the_geom) ")

        self.store_dataset_origin!(options)
      end
    end

    def merge_into_pending_data!
      ActiveRecord::Base.transaction do
        update_dataset_ref
        if self.connection.table_exists?(TEMPORARY_PREPRODUCTION_TABLE)
          p "inserting #{temp_table_name} into #{TEMPORARY_PREPRODUCTION_TABLE}"
          self.connection.execute(
            "INSERT INTO #{TEMPORARY_PREPRODUCTION_TABLE} (state, cd, name, the_geom, level, dataset_id)
             SELECT                                        state, cd, name, the_geom, level, dataset_id
             FROM #{temp_table_name}")
          clear_temp_table!(temp_table_name)
        else
          self.connection.execute("ALTER TABLE #{temp_table_name} RENAME TO #{TEMPORARY_PREPRODUCTION_TABLE}")
          self.connection.execute("DROP INDEX IF EXISTS #{temp_table_name}_geom_idx;")
        end
      end
      add_indexes_and_contraints
    end

    def self.normalize_data!(target_table=nil)
      puts "Normoalizing data before making live..."
      target_table ||= TEMPORARY_PREPRODUCTION_TABLE
      connection = ActiveRecord::Base.connection

      # raise 'before you run this, note that we normalized data in a non-standard way. See note in code.'
      # NOTE: Typically, "At Large" districts are normalized to "0" since it's technically not a 1st district.
      # This code, (line 180) normalizes to 1 when we probably should have chosen 0. Be sure to update dependent code

      # There are some differences in district names between the new 113th congress data from census.gov, and what we're
      # getting from votesmart. Since we know we're getting 112th congress data from votesmart, we're going to ignore
      # these differences for now. Once we start getting new data from them, we'll check the differences again#
      # (mcommons, rake one_off:test_tigress_data) and add any needed data fixes.
      puts "  ...remove common district names"
      ['State Legislative District','State Legislative Subdistrict','State House District', 'General Assembly District', 'Assembly District', 'State Senate District', 'House District', 'District'].each do |phrase|
        connection.execute "UPDATE #{target_table} SET name = trim(replace(name, '#{phrase}', '')) WHERE level LIKE 'state_%'"
      end

      puts '  ...clear double spaces'
      connection.execute "UPDATE #{target_table} SET name = replace(name, '  ', ' ')"

      puts '  ...give ZZ (undefined) districts better name'
      connection.execute "UPDATE #{target_table} SET name = 'not defined' WHERE name like '%ZZ%'"
      connection.execute "UPDATE #{target_table} SET name = replace(name, '^s ', '') WHERE name ~ '^Z'"

      puts "  ...remove roman numerals"
      %w(I II III IV V VI VII VIII).each_with_index do |numeral, index|
        connection.execute "UPDATE #{target_table} SET name = #{index + 1} WHERE name = '#{numeral}'"
      end

      puts "  ...remove 'County No. ' from NH state levels"
      connection.execute "UPDATE #{target_table} SET name = replace(name, 'County No. ', '') WHERE state = '33' AND level like 'state_%'"

      puts "  ...remove 'HD-' from district names for SC state lower"
      connection.execute "UPDATE #{target_table} SET name = replace(name, 'HD-', '') WHERE state = '45' AND level = 'state_lower'"

      # TODO once this is live, remove the trim_leading_zeros() calls from Location.

      puts '  ...use numeric cd number for name if name is null'
      connection.execute "UPDATE #{target_table} SET name = cd WHERE name IS NULL OR name = ''"

      puts "  ...set most at large districts to 1"
      connection.execute "UPDATE #{target_table} SET name = '1' WHERE level = 'federal' AND (name ~* 'at large' OR name = '98' OR name = '00')" #This is typically normalized at 0. we made an error.
      connection.execute "UPDATE #{target_table} SET name = '98' WHERE state = '72' AND level = 'federal'" # naming it 98 because that's how it was before the 113 congress update
      connection.execute "UPDATE #{target_table} SET name = '1' WHERE level = 'federal' AND (name = '' or name IS NULL)"

      puts "  ...trim leading zeros from state district names"
      connection.execute "UPDATE districts SET name = regexp_replace(name, '^0+', '') WHERE name ~ '^0+'"

      # puts "  ...21st to Twenty-First"
      # class TempDistrict < District
      #   self.table_name = "temp_districts"
      # end
      # TempDistrict.all(:conditions=>["state = '25' AND level = 'state_lower' AND name ~ '^[0-9]'"]).each do |district|
      #   district.update_attributes(:name => numbers_to_words(district.name))
      # end

      # puts "  ...rename Grand-Isle... to Grand Isle..."
      # self.connection.execute "UPDATE temp_districts SET name = replace(name, 'Grand-Isle', 'Grand Isle') WHERE state = '50' AND name ~ 'Grand Isle'"
    end

    def merge_into_live_data!(target_table=nil)
      target_table ||= temp_table_name
      self.class.normalize_data!(target_table)
      puts "merging into LIVE #{PRODUCTION_TABLE} table"
      ActiveRecord::Base.transaction do
        p "inserting #{target_table} into #{PRODUCTION_TABLE}"
        update_dataset_ref(target_table)
        self.connection.execute(
          "INSERT INTO #{PRODUCTION_TABLE} (state, cd, name, the_geom, level, dataset_id)
           SELECT                           state, cd, name, the_geom, level, dataset_id
           FROM #{target_table}")
        clear_temp_table!(target_table)
        Scheduler.schedule!
      end
    end

    def self.temp_to_live!
      self.normalize_data!
      puts "Replacing live table with newly imported data"
      ActiveRecord::Base.transaction do
        connection = ActiveRecord::Base.connection
        connection.execute "ALTER TABLE #{PRODUCTION_TABLE} RENAME TO districts_#{Date.today.strftime('%Y_%m_%d')}"
        connection.execute "ALTER TABLE #{TEMPORARY_PREPRODUCTION_TABLE} RENAME TO #{PRODUCTION_TABLE}"
        Scheduler.schedule!
      end
    end

    def zip_files_directory; raise 'implement in subclass'; end
    def shape_files_directory; raise 'implement in subclass'; end

    def remove_unneeded_columns!(table_name)
      # REQUIRED    District(gid: integer, state: string, cd: string, name: string, the_geom: string, level: string, district_id: integer)
      %w(ogc_fid chng_type eff_date lsad namelsad new_code reltype1 reltype2 reltype3 reltype4 reltype5 rel_ent1 rel_ent2 rel_ent3 rel_ent4 rel_ent5 relate cdsessn vintage funcstat cdtyp aland awater mtfcc geoid intptlat intptlon statens).each do |column_name|
        self.connection.execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name};" if self.connection.column_exists? table_name, column_name
      end
    end

    def validate_coordinate_system
      fake_class_name = temp_table_name.camelize
      eval("class #{fake_class_name} < District; self.table_name = '#{temp_table_name}'; end")
      cords = fake_class_name.constantize.first.polygon_coordinates[0][0]
      puts 'ERROR: There was a problem with your coordinate system for #{temp_table_name}. You might need to import with a different EPSG value' if cords[0].to_i > 1000
    end

    def clear_temp_table!(table_name=nil)
      table_name ||= temp_table_name
      self.connection.drop_table(table_name) if self.connection.table_exists?(table_name)
    end

    def create_path_and_clean!(path,forced=false)
      puts "creating and cleaning path: #{path}"
      `mkdir -p #{path}`
      `rm #{path}/* -rf` if !self.already_cleaned && forced
      self.already_cleaned = true
    end

    private


    # With all the merging and copying these sometimes get removed.
    def add_indexes_and_contraints(target_table=nil)
      target_table ||= TEMPORARY_PREPRODUCTION_TABLE
      add_column(target_table, :expires_at, :datetime)
      add_column(target_table, :valid_at, :datetime)

      sql_statements_to_execute = [
        "ALTER TABLE #{target_table} ADD COLUMN #{District.primary_key} SERIAL;",
        "UPDATE #{target_table} SET #{District.primary_key} = nextval(pg_get_serial_sequence('#{target_table}','#{District.primary_key}'));",
        "CREATE UNIQUE INDEX #{District.primary_key}_idx ON #{target_table} (#{District.primary_key});",
        "ALTER TABLE #{target_table} ADD CONSTRAINT #{District.primary_key}_pk PRIMARY KEY USING INDEX #{District.primary_key}_idx;",
        "CREATE INDEX the_geom_idx ON #{target_table} USING GIST (the_geom)",
        "CREATE INDEX valid_at_idx ON #{target_table}(valid_at);",
        "CREATE INDEX expires_at_idx ON #{target_table}(expires_at);",
        "CREATE INDEX level_idx ON #{target_table}(level);",
        "CREATE INDEX state_idx ON #{target_table}(state);",
        "CREATE INDEX name_idx ON #{target_table}(name);"
      ]

      { #adding GEOM constraints
        :enforce_dims_the_geom => '(st_ndims(the_geom) = 2)',
        :enforce_geotype_the_geom => '(geometrytype(the_geom) = \'MULTIPOLYGON\'::text OR the_geom IS NULL)',
        :enforce_srid_the_geom => "(st_srid(the_geom) = (#{District::DEFAULT_EPSG_SRID_CODE}))"
      }.each do |name,constraint|
        sql_statements_to_execute << "ALTER TABLE #{target_table} ADD CONSTRAINT #{name} CHECK #{constraint}"
      end

      sql_statements_to_execute.each do |sql_to_execute|
        begin
          self.connection.execute(sql_to_execute)
        rescue
        end
      end
      puts 'added constraints'
    end

    def add_column(table_name,column_name,column_type)
      self.connection.add_column table_name, column_name, column_type unless self.connection.column_exists? table_name, column_name
    end

    def update_dataset_ref(target_table=nil)
      target_table ||= temp_table_name
      [:valid_at,:expires_at].each do |column|
        add_column(target_table, column, :datetime)
      end
      add_column(target_table, :dataset_id, :integer)
      self.connection.execute "UPDATE #{target_table} SET dataset_id = '#{self.origin.id}'"
    end

    def fetch_epsg_encoding!
      # Example .prj file contents:  'GEOGCS["GCS_GRS_1980",DATUM["D_GRS_1980",SPHEROID["GRS_1980",6378137,298.2572221]],PRIMEM["Greenwich",0],UNIT["Degree",0.0174532925199433]]'
      prj_files = Dir["#{shape_files_directory}/**/*.{prj,PRJ}"]
      if prj_files.empty?
        raise 'Your *.prj files got deleted in a previous run.  Prj files must be unzipped again, possibly by running this command like so: class.import_and_process!(:unzip => true)'
      else
        json_results = RestClient.get 'http://prj2epsg.org/search.json', :params => {:terms => File.read(prj_files[0])} #assume they're all the same
        epsg_results = JSON.parse(json_results)['codes']
        target_code = epsg_results[0]['code']
        if epsg_results.size > 1
          all_epsg_codes = epsg_results.map{|h| h['code']}
          puts "WARNING: more than one ESPG/SRID cod received. Currently trying #{target_code}. If you have trouble with large floats in your coordinate results, then try import this dataset with an alternative code: #{all_epsg_codes[0..-1].to_s}."
        end
        prj_files.each { |f| File.delete(f) }
        self.epsg_code ||= target_code
      end
    end

    def import_shapefile_processor
      files_to_import = Dir.glob("#{shape_files_directory}/**/*.shp", File::FNM_CASEFOLD)
      raise "There are no shp files to import in #{shape_files_directory}! Try unzipping them first!" unless files_to_import.any?
      p "importing #{files_to_import.length} shape files into temp tables"
      seen_table_names = []
      files_to_import.each do |shape_file|
        table_name = yield shape_file
        p "loading #{shape_file} into #{table_name}"
        self.clear_temp_table!(table_name) if !seen_table_names.include?(table_name)
        import_file(shape_file, table_name,seen_table_names.include?(table_name))
        seen_table_names << table_name #append as tables exist
      end
      puts 'done!'
    end

    def download_file(zip_file_path,zip_file,force=nil)
      # census defaults to 550kb/s max.  aria2c helps get around this.
      @download_command ||= force || `which command aria2c`.include?('/aria2c') ? :aria2c : :wget
      @download_options ||= DOWNLOAD_COMMAND_OPTIONS[force || @download_command || :wget] + zip_files_directory

      puts "Downloading #{zip_file_path}#{zip_file}..."
      puts " #{zip_file_path}#{zip_file}"
      `#{@download_command} #{zip_file_path}#{zip_file} #{@download_options}` unless File.exists?("#{zip_files_directory}/#{zip_file}")
    end

    def import_file(file_name,table_name,append=false)
      append = append ? '-append' : ''
      epsg_conversion = if self.epsg_code == District::DEFAULT_EPSG_SRID_CODE
         "-a_srs EPSG:#{District::DEFAULT_EPSG_SRID_CODE}"
       else
         "-s_srs EPSG:#{self.epsg_code} -t_srs EPSG:#{District::DEFAULT_EPSG_SRID_CODE}"
       end
      config_info = "host=#{self.database_config[:host]} user=#{self.database_config[:username]} dbname=#{self.database_config[:database]} port=5432 password=#{self.database_config[:password]}"
      `ogr2ogr -f PostgreSQL PG:\"#{config_info}\" #{file_name} -nlt MULTIPOLYGON #{epsg_conversion} -lco GEOMETRY_NAME=the_geom -nln #{table_name} #{append} -skipfailures`
    end

  end
end