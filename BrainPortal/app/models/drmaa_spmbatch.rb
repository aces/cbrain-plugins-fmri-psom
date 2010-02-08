
#
# CBRAIN Project
#
# DrmaaSpmbatch model as ActiveResource
#
# Original author: 
#
# $Id: model.rb 700 2009-12-21 19:14:58Z tsherif $
#

#A subclass of DrmaaTask to launch spmbatch.rb.
class DrmaaSpmbatch < DrmaaTask

  Revision_info="$Id: model.rb 700 2009-12-21 19:14:58Z tsherif $"

  def self.has_args?
    true
  end
  
  def self.get_default_args(params = {}, saved_args = nil)
    file_ids         = params[:file_ids]
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

    collection = userfiles[0]
    user_id          = params[:user_id]
    bourreau_id      = params[:bourreau_id]
    data_provider_id = params[:data_provider_id]
    collection_id = collection.id

    #Get the list of all available matlab Files
    unless batch_files = Userfile.find(:all, :conditions =>  ["(userfiles.name LIKE ?)", "%.m"])
      cb_error "No SPM8 Batch found: Batch have to be a Matlab .m script file create by Batch Editor in SPM8"
    end
    
    state = collection.local_sync_status
    cb_error "Error: in order to speed up the process, it must first have been synchronized.\n" +
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
    {  :file_args        => file_args,
       :collection_id    => collection_id,
       :data_provider_id => data_provider_id,
       :bourreau_id      => bourreau_id,
       :batch_files      => batch_files,
    }
  end

  def self.launch(params)
    
    batchs_files = params[:batch_files]
    file_args  = params[:file_args]
    flash = ""    
    user_id          = params[:user_id]
    collection_id    = params[:file_ids]
    bourreau_id      = params[:bourreau_id]
    data_provider_id = params[:data_provider_id]
    description      = params[:description]
    validation       = params[:noValidation]
    save_all         = params[:saveAll]
    
    spawn_this = file_args.size > 3   #have to modify that to 3
 
     CBRAIN.spawn_with_active_records_if(spawn_this,user,"spm8Batch launcher") do
      file_args.each do |file|
        subjects = file[:name]
        bourreau_params = {:subjects => file}       
        bourreau_params[:collection_id] = collection_id[0]
        bourreau_params[:validation] = validation
        bourreau_params[:save_all] = save_all
        bourreau_params[:batchs_files] = batchs_files
        bourreau_params[:data_provider_id] = data_provider_id
        
                
        # Create the object, send it to Bourreau
        spm8 = DrmaaSpmbatch.new  # a blank ActiveResource object
        spm8.user_id      = user_id
        spm8.bourreau_id  = bourreau_id unless bourreau_id.blank?
        spm8.description  = description       
        spm8.params       =  bourreau_params
        spm8.save
        flash += "Started spmBatch on subjects '#{subjects}'.\n" unless spawn_this
      end
    end
    flash += "Started spmBatch on #{file_args.size} subjects.\n" if spawn_this
    flash
  end

  def self.save_options(params)
    {}
  end
end

