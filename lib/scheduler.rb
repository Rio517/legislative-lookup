class Scheduler

  SESSION_CHANGE_DATES = {
    :datetime_2002 => DateTime.parse('2003-01-30'),
    :datetime_2012 => DateTime.parse('2013-01-30'),
    :datetime_2013 => DateTime.parse('2014-01-30'),
    :datetime_2014 => DateTime.parse('2015-01-30'),
    :datetime_2015 => DateTime.parse('2016-01-30'),
    :datetime_2016 => DateTime.parse('2017-01-30')
  }

  VALID_2002_to_2014      = {:valid_at => SESSION_CHANGE_DATES[:datetime_2002],:expires_at => SESSION_CHANGE_DATES[:datetime_2014]}
  VALID_2002_to_2015      = {:valid_at => SESSION_CHANGE_DATES[:datetime_2002],:expires_at => SESSION_CHANGE_DATES[:datetime_2015]}
  CD113_DELAYED_TO_2014   = {:census2011 => VALID_2002_to_2014, :census2013 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}}
  CD113_DELAYED_TO_2015   = {:census2011 => VALID_2002_to_2015, :census2013 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2015]}}
  CD112_EXTENDED_NO_CD113 = {:census2011 => VALID_2002_to_2014, :census2013 => {:valid_at => nil}}


  STANDARD_VALID_PERIODS = {  # Used during import
    :census2011  => {:valid_at => SESSION_CHANGE_DATES[:datetime_2002], :expires_at => SESSION_CHANGE_DATES[:datetime_2012]},
    :census2013  => {:valid_at => SESSION_CHANGE_DATES[:datetime_2012]},
    :ky113       => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]},
    :me113       => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]},
    :mt113       => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]},
    :pa113       => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]},
    :tx_h309     => {:valid_at => SESSION_CHANGE_DATES[:datetime_2013], :expires_at => SESSION_CHANGE_DATES[:datetime_2014]}
  }

  VALID_DATE_EXCEPTIONS = {
    #'AK' => {}, Couldn't import GIS files - need to re-eval cd datasets for most valid info.
    'AL' => {:state_lower => CD113_DELAYED_TO_2014,
             :state_upper => CD113_DELAYED_TO_2014},
    'KY' => {:state_lower => CD112_EXTENDED_NO_CD113.merge(:ky113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}),
             :state_upper => CD112_EXTENDED_NO_CD113.merge(:ky113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]})},
    # Technically, Maine adheres to the following, but we were unable to import ME. Census from 2013 had a map that was mostly right.
    # 'ME' => {:state_lower => CD112_EXTENDED_NO_CD113.merge(:me113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}),
    #          :state_upper => CD112_EXTENDED_NO_CD113.merge(:me113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]})},
    'ME' => {:state_lower => CD112_EXTENDED_NO_CD113.merge(:census2013 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}),
             :state_upper => CD112_EXTENDED_NO_CD113.merge(:census2013 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]})},
    'MI' => {:state_lower => CD113_DELAYED_TO_2015,
             :state_upper => CD113_DELAYED_TO_2015},
    'MT' => {:state_lower => CD112_EXTENDED_NO_CD113.merge(:mt113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}),
             :state_upper => CD112_EXTENDED_NO_CD113.merge(:mt113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]})},
    'PA' => {:state_lower => CD112_EXTENDED_NO_CD113.merge(:pa113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]}),
             :state_upper => CD112_EXTENDED_NO_CD113.merge(:pa113 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2014]})},
    'TX' => {:state_lower => {:tx_h309 => {:valid_at => SESSION_CHANGE_DATES[:datetime_2013], :expires_at => SESSION_CHANGE_DATES[:datetime_2014]}, 
                              :census2011 => {:expires_at => SESSION_CHANGE_DATES[:datetime_2012]}, 
                              :census2013 => {:expires_at => SESSION_CHANGE_DATES[:datetime_2016]}}
                              },  #census2013 expires at end of 2016!!!
  }

  def self.schedule!
    STANDARD_VALID_PERIODS.each do |dataset_label,attributes|
      dataset = Dataset.where(:source_identifer => dataset_label).first
      District.where(:dataset_id => dataset.id).where("cd != 'ZZ'").update_all(attributes) if dataset
    end
    VALID_DATE_EXCEPTIONS.each do |state, schedule|
      schedule.each do |level, datasets|
        datasets.each do |dataset_label,attributes|
          dataset = Dataset.where(:source_identifer => dataset_label).first
          District.where(:state => District::STATES[state], :level => level, :dataset_id => dataset).where("cd != 'ZZ'").update_all(attributes)
        end
      end
    end
    puts 'Done scheduling'
  end

  def self.public_options
    Scheduler::SESSION_CHANGE_DATES.map{|label,value| [label.to_s.gsub('datetime_', 'post-'),value + 1.day]}.unshift(['Current', DateTime.now])
  end


end