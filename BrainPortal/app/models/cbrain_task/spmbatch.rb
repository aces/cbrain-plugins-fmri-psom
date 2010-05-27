
#
# CBRAIN Project
#
# Spmbatch model
#
# Original author: 
#
# $Id$
#

#A subclass of CbrainTask::PortalTask to launch spmbatch.rb.
class CbrainTask::Spmbatch < CbrainTask::PortalTask

  Revision_info="$Id$"

  def self.properties #:nodoc:
    { :no_submit_button => true } # I create my own in my view.
  end

  def before_form #:nodoc:
    params = self.params

    file_ids         = params[:interface_userfile_ids]
    userfiles = []
    file_ids.each do |id|
      userfiles << Userfile.find(id)
    end

    # we must have a single FileCollection in argument
    unless userfiles.size == 1
      cb_error "Error: you should select only one Collection for this task.\n"
      #on retourne un code d'erreur trop d'argument fourni en entrer
      #raise blabla    
    end    
    
    unless userfiles[0].is_a?(FileCollection)
      cb_error "Error: The file selected is not a Collection.\n"
    end

    collection       = userfiles[0]
    collection_id    = collection.id

    user             = self.user

    #Get the list of all available matlab Files
    unless batch_files = Userfile.find_all_accessible_by_user(user, :conditions =>  ["(userfiles.name LIKE ?)", "%.m"])
      cb_error "No SPM8 Batch found: Batch have to be a Matlab .m script file create by Batch Editor in SPM8"
    end
    
    state = collection.local_sync_status
    cb_error "Error: Your file collection #{collection.name} must first be synchronized.\n" +
          "In the file manager, click on the collection then on the 'synchronize' link." if
          ! state || state.status != "InSync"

    # Get the list of all subjects inside the collection; we only
    # look one level deep inside the directory.
    dirs_inside  = collection.list_first_level_dirs
    suj_dirs = []
    dirs_inside.each do |basename|
      suj_dirs << File.basename(basename)
    end
    cb_error "There are no subjects directory in this FileCollection!" unless suj_dirs.size > 0

    file_args = []
    suj_dirs.each { |dir_name|
      file_args << {
        :name             => dir_name,
      }    
    }
    self.params.merge!(
    {  :file_args        => file_args,
       :collection_id    => collection_id,
       :batch_files      => batch_files,
    })
    ""
  end

  def final_task_list #:nodoc:
    
    params = self.params

    batchs_files = params[:batch_files]
    file_args    = params[:file_args]

    collection_id    = params[:collection_id]
    bourreau_id      = params[:bourreau_id]
    data_provider_id = params[:data_provider_id]
    description      = params[:description]
    validation       = params[:noValidation]
    save_all         = params[:saveAll]
    
    task_list = []

      file_args.each do |file|
        subjects = file[:name]
        
        # Create the object
        spm8 = self.clone
        spm8.params[:subjects] = file

        task_list << spm8
      end

    task_list
  end

end

