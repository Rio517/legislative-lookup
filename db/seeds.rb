connection = ActiveRecord::Base.connection
config = connection.instance_variable_get(:@config) #{:adapter=>"postgresql", :database=>"congress_development", :username=>"postgres", :password=>nil, :host=>"127.0.0.1"}
config_sql = "-h #{config[:host]} -U #{config[:username]}"

`tar xvfz db/test_data.sql.tar.gz`
file_name = "#{Rails.root}/db/test_data.sql"
seed_sql_file = File.expand_path(file_name)

raise "Missing #{file_name}" if !File.exists?(seed_sql_file)
puts config['adapter']
raise "This application only supports postgres with postgis, not #{config[:adapter]}" unless %w[postgis postgres postgresql].include?(config[:adapter])

connection.execute 'CREATE EXTENSION postgis' rescue puts 'postis extension already exists'

`psql #{config_sql} #{config[:database]} < #{file_name}`
`rm #{file_name}`

temp_districts = District.table_name + '_test_data'
temp_datasets = Dataset.table_name + '_test_data'

def process_imported_table(existing_table, new_table)
  ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS #{existing_table}; ALTER TABLE #{new_table} RENAME TO #{existing_table}"
  ActiveRecord::Base.connection.execute "ALTER TABLE #{existing_table} ADD PRIMARY KEY (id);"
end

ActiveRecord::Base.transaction do
  puts "dropping and renaming tables"
  process_imported_table(District.table_name, temp_districts)
  process_imported_table(Dataset.table_name, temp_datasets)
end