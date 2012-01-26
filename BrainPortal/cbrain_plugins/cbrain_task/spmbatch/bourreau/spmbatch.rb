
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

# A subclass of ClusterTask to run bigseed.
#
# Original author: Mathieu Desrosiers
class CbrainTask::Spmbatch < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
     params = self.params 

     command_args = " "

     subjects = params[:file_args]["0"] || params[:subjects]  # changed struct: NEW || OLD
     name = subjects[:name]

     if subjects.has_key?(:exclude)
       self.addlog("Subjects: #{name} succesfully excluded") 
       return true
     end
     
     self.addlog("Subjects: #{name}")
     collection_id = params[:collection_id]
     collection = Userfile.find(collection_id)
     unless collection
       self.addlog("Could not find active record entry for FileCollection '#{collection_id}'.")      
       return false
     end

     self.results_data_provider_id ||= collection.data_provider_id
     
     collection.sync_to_cache
     self.addlog("Study full path: #{collection.cache_full_path.to_s}")
     rootDir = File.join(collection.cache_full_path.to_s,name)
     self.addlog("Task root directory: #{rootDir}")
     
     safe_symlink(rootDir,name)

     batch_names = []
     batchs_files = params[:batch_file_ids].values
     batchs_files.each_with_index { |batch_id,idx|      
       batch = Userfile.find(batch_id)
       batch.sync_to_cache
       batch_name = batch.cache_full_path.to_s
       batch_names.push(batch_name)
       self.addlog("Batch[#{idx}] to process: #{batch_name}") 
       command_args += " #{batch_name}"     
     }
     
     command_args += " --doCleanUp "   if subjects.has_key?(:doCleanUP)
     command_args += " --doFieldMap "  if subjects.has_key?(:doFieldMap)            
     self.params[:command_args] = command_args  
     self.addlog("Full command arguments: #{command_args}")
     true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    command_args = params[:command_args]
    subjects     = params[:file_args]["0"] || params[:subjects]  # changed struct: NEW || OLD
    name         = subjects[:name]        
    command      = "bigseed ./#{name} #{command_args}"
    
    [
    "unset DISPLAY",
    "echo \"\";echo Showing ENVIRONMENT",
    "env | sort",
    "echo \"\";echo Starting SpmBatch",
    "echo Command: #{command}",
    "#{command}"
    ]
  
  end
  
  def save_results #:nodoc:
    params       = self.params
    subjects     = params[:file_args]["0"] || params[:subjects]  # changed struct: NEW || OLD
    name = subjects[:name]
    save_all = ! params[:save_all]
    self.addlog("saveall=#{params[:save_all].inspect}")

    collection_id = params[:collection_id]
    collection = Userfile.find(collection_id)
    source_userfile = FileCollection.find(collection_id)
    
    self.addlog("Study full path: #{collection.cache_full_path.to_s}")
    rootDir = File.join(collection.cache_full_path.to_s,name)
    self.addlog("Task root directory: #{rootDir}")

    data_provider_id = self.results_data_provider_id
    self.addlog("data_provider_id= #{data_provider_id}")
    spmbatchresult = safe_userfile_find_or_new(FileCollection,
        :name             => name,
        :data_provider_id => data_provider_id
    )
    
    self.addlog("spmbatchresult = #{spmbatchresult}")
    self.addlog("spmbatchresult = #{spmbatchresult.name}")
    # Main location for output files
    safe_mkdir("spmbatch_out",0700)           
    safe_mkdir("spmbatch_out/#{name}",0700)
    safe_mkdir("spmbatch_out/#{name}/scripts",0700)
    FileUtils.cp(Dir.glob("#{rootDir}/*.m"),"spmbatch_out/#{name}/scripts") rescue true
    FileUtils.cp(Dir.glob("#{rootDir}/*.ps"),"spmbatch_out/#{name}/scripts") rescue true
    FileUtils.cp_r("#{rootDir}/spmbatch_log_dir","spmbatch_out/#{name}") rescue true
    FileUtils.cp("#{rootDir}/spmbatch_master.log", "spmbatch_out/#{name}/spmbatch_log_dir/spmbatch_master.log") rescue true  
    
    self.addlog("Just results and logs will be saved")
    #find where the results have been save
    #this function assume that there is a directory call spmbatch_log_dir
    result_file = "#{rootDir}/spmLog/#{name}_resultat_dir.txt"
    self.addlog("Here result file: #{result_file}")
    if File.exist?(result_file) && !File.zero?(result_file)
      self.addlog("Opening file: #{result_file}")
      File.open(result_file,'r').each_line do |resultat_dir|
        self.addlog("archive results in directory: #{resultat_dir}")
        self.addlog("Create an archive with results in directory: #{resultat_dir}")          
        FileUtils.cp_r("#{resultat_dir}","spmbatch_out/#{name}") rescue true    
      end
    end

    if save_all
      self.addlog("Everything should be save")
    end

    if spmbatchresult.save
      spmbatchresult.cache_copy_from_local_file("spmbatch_out/#{name}")
      spmbatchresult.move_to_child_of(source_userfile)
      self.addlog("Saved new spmBatch result file #{spmbatchresult.name}.")
      params[:spmbatchresult_id] = spmbatchresult.id
      self.addlog_to_userfiles_these_created_these( [ collection ], [ spmbatchresult ] )
      return true
    else
      self.addlog("Could not save back result file '#{spmbatchresult.name}'.")
      params.delete(:spmbatchresult_id)
      return false
    end
    
    self.addlog("Have a nice day!")      # never executed?

  end

end

