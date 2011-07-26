
#
# CBRAIN Project
#
# Spmbatch model
#
# Original author: 
#
# $Id$
#

#A subclass of PortalTask to launch spmbatch.rb.
class CbrainTask::Spmbatch < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_submit_button => true } # I create my own in my view.
  end

  def before_form #:nodoc:
    params = self.params

    file_ids         = params[:interface_userfile_ids] || []
    cb_error "Error: you should select only one Collection for this task.\n" if file_ids.size != 1
    
    collection_id    = file_ids[0]
    collection       = Userfile.find(collection_id)
    unless collection.is_a?(FileCollection)
      cb_error "Error: The file selected is not a FileCollection.\n"
    end

    state = collection.local_sync_status
    cb_error "Error: Your file collection #{collection.name} must first be synchronized.\n" +
          "In the file manager, click on the collection then on the 'synchronize' link." if
          ! state || state.status != "InSync"

    user             = self.user

    #Get the list of all available matlab Files
    batch_files = Userfile.find_all_accessible_by_user(user, :conditions =>  ["(userfiles.name LIKE ?)", "%.m"])
    unless batch_files && batch_files.size > 0
      cb_error "No SPM8 Batch found: Batch have to be a Matlab .m script file create by Batch Editor in SPM8"
    end
    
    # Get the list of all subjects inside the collection; we only
    # look one level deep inside the directory.
    dirs_inside  = collection.list_first_level_dirs
    cb_error "There are no subjects directory in this FileCollection!" unless dirs_inside.size > 0

    file_args = {}
    dirs_inside.each_with_index do |basename,idx|
      file_args[idx.to_s] = { :name => File.basename(basename) }
    end

    self.params.merge!( {  
       :collection_id    => collection_id,
       :file_args        => file_args,
       :batch_files      => batch_files
       }
    )
    ""
  end

  def final_task_list #:nodoc:
    
    params = self.params

    file_args    = params[:file_args]

    task_list = []

    file_args.values.each do |file|

      next if ! file[:exclude].blank?

      # Create the object
      spm8 = self.clone
      spm8.params[:file_args] = { "0" => file }

      task_list << spm8
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :file_args => true, :collection_id => true, :command_args => true, :batch_file_ids => true }
  end

end

