
#
# CBRAIN Project
#
# ClusterTask Model PsomPipelineLauncher
#
# $Id$
#


# A subclass of ClusterTask to run a PSOM pipeline. Must be
# subclassed for specific pipelines.
class CbrainTask::PsomPipelineLauncher < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  # Used internally by PsomPipelineLauncher to encapsulate the XML rendering
  # needed by the PSOM pipeline builder
  class PsomXmlEvaluator #:nodoc:

    Revision_info=CbrainFileRevision[__FILE__]

    # Similar to the ERB:Util method for HTML, to allow escaping of XML text
    def xml_escape(s) #:nodoc:
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;").gsub(/'/,"&apos;")
    end
    alias x xml_escape #:nodoc:

    # Transforms an identifier into a 'saner' one, that is, it must start
    # with a letter and contain only letters, digits or _.
    #
    #   sane_id('ab_23')             => "ab_23"
    #   sane_id('1234')              => "X_1234"
    #   sane_id("+12-john_o'connor") => "X__12_john_o_connor"
    def sane_id(s)
      return s if s =~ /^[a-zA-Z]\w+$/
      "X_#{s}".gsub(/\W/,"_")
    end
  end

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params || {}

    subtasks = [] # declared at beginning so it's seen by the method's rescue clause cleanup.

    # Record code versions
    self.addlog_revinfo(CbrainTask::PsomPipelineLauncher)
    svninfo_outerr = self.tool_config_system("svn info \"$PSOM_ROOT\" 2>&1")
    psom_rev = svninfo_outerr[0] =~ /Revision:\s+(\d+)/ ? Regexp.last_match[1] : "???"
    self.addlog("PSOM rev. #{psom_rev}")

    # Sync input data
    fmri_study = FmriStudy.find(params[:interface_userfile_ids][0])
    fmri_study.sync_to_cache

    # -----------------------------------------------------------------
    # Create the XML input description for the particular PSOM pipeline
    # -----------------------------------------------------------------
    self.addlog("Building pipeline description")

    xml_template = self.get_psom_launcher_template_xml
    xml_erb      = ERB.new(xml_template,0,">")
    xml_erb.def_method(PsomXmlEvaluator, 'render(task, params, fmri_study)', "(PSOM XML for #{self.name})")
    begin
      xml_filled = PsomXmlEvaluator.new.render(self, params, fmri_study)
    rescue => ex
      self.addlog("Error building XML input file for pipeline builder.")
      self.addlog_exception(ex)
      return false
    end

    launcher_xml_file = self.name.underscore + ".xml"
    File.open(launcher_xml_file, "w") do |fh|
      fh.write xml_filled
    end

    pipe_desc_dir = self.pipeline_desc_dir
    safe_mkdir(pipe_desc_dir)
    return false unless self.build_pipeline(launcher_xml_file, pipe_desc_dir)

    # Detect situations of restarts (when subtasks already exists).
    if self.run_number > 1 && self.psom_subtasks.count > 0
      self.addlog("Skipping setup of subtasks, as we are restarting everything.")
      return true
    end

    # -----------------------------------------------------------------
    # Read the XML pipeline description for the PSOM jobs
    # -----------------------------------------------------------------

    # IMPORTANT NOMENCLATURE NOTE: in this code,
    #  * the word 'job' is used to identify PSOM jobs
    #  * the word 'task' is used to identify CBRAIN tasks
   
    self.addlog("Creating subtasks")

    # Extract the list of jobs and index it
    pipeline_xml    = File.read("#{pipe_desc_dir}/pipeline.xml")
    pipeline_struct = Hash.from_xml(pipeline_xml)

    # Debug: create a DOT formated file of the job dependencies
    dotout = create_dot_graph(pipeline_struct);
    File.open("#{self.name.underscore}.dot","w") { |fh| fh.write(dotout) } # for debugging

    # For each job, build lists of 'follower' and 'predecessor' jobs
    # NOTE: cannot store these lists inside the job objects themselves, as it would confuse their to_s() renderers
    jobs                   = pipeline_struct['pipeline']['job']
    jobs                   = [ jobs ] unless jobs.is_a?(Array)
    jobs_by_id             = jobs.index_by { |job| job['id'] }
    job_id_to_successors   = {}
    job_id_to_predecessors = {}
    jobs.each do |job|
      job_id       = job['id']
      dependencies = (job['dependencies'] || {})['dependency'] || []
      dependencies = [ dependencies] unless dependencies.is_a?(Array)
      job_id_to_successors[job_id]   ||= []
      job_id_to_predecessors[job_id] ||= []
      dependencies.each do |depjobid|
        job_id_to_predecessors[job_id] << depjobid
        job_id_to_successors[depjobid] ||= []
        job_id_to_successors[depjobid] << job_id
      end
    end

    # Remove redundant dependencies.
    # If A -> B, B -> C and A -> C, then A -> C is redundant.
    remove_redundant_dependencies(job_id_to_predecessors,job_id_to_successors)

    # -----------------------------------------------------------------
    # Create a topologically sorted array of jobs
    # -----------------------------------------------------------------

    # Identify the set of jobs that are 'starter' jobs (with no dependencies)
    jobs_queue   = jobs.select { |job| job_id = job['id'] ; job_id_to_predecessors[job_id].empty? }

    # Stuff updated while processing the jobs list
    ordered_jobs = [] # Our final list
    seen_job_ids = {} # Record what jobs we've seen
    max_postponing = 10000 # stupid counter to detect infinite loops
    job_id_to_level = {} # for pretty indentation of CbrainTasks

    # Main loop through our queue of jobs
    while jobs_queue.size > 0
      #puts_blue "QUEUE: " + show_ids(jobs_queue)

      # Current job is extracted from head of processing queue
      job    = jobs_queue.shift
      job_id = job['id']
      next if seen_job_ids[job_id]

      # All predecessors must be ordered already. Otherwise, push back at end of queue
      predecessor_ids = job_id_to_predecessors[job_id] || []
      unless predecessor_ids.all? { |pid| seen_job_ids[pid] }
         jobs_queue << job # postpone it
         max_postponing -= 1
         cb_error "It seems we have a job cycle in the pipeline description." if max_postponing < 1
         next
      end

      # Identify a 'level' for the job, which is 1 more than the highest level among predecessors
      max_level = 1
      predecessor_ids.each do |pid|
         prec_level = job_id_to_level[pid] || 1
         max_level = prec_level + 1 if prec_level >= max_level # >= important, not simply >
      end
      job_id_to_level[job_id] = max_level

      # Push the job on the 'ordered' list, mark it as processed.
      ordered_jobs << job
      seen_job_ids[job_id] = true

      # Push all unprocessed followers on the queue
      follower_ids = job_id_to_successors[job_id] || []
      follower_ids.each do |follower_id|
        next if seen_job_ids[follower_id]
        follower = jobs_by_id[follower_id]
        cb_error "Internal error: can't find follower job with ID '#{follower_id}' ?!?" unless follower
        jobs_queue.reject! { |j| j['id'] == follower_id }
        jobs_queue << follower
      end

    end

    # Check that all jobs in the initial list were reached and ordered.
    missing_jobs = jobs.select { |job| ! seen_job_ids[job['id']] }
    cb_error "The graph of jobs seems to contain #{missing_jobs.size} jobs unconnected to the rest of the graph?!?" if missing_jobs.size > 0

    # Debug 2: create a DOT formated file of the job dependencies,
    # this time with redundant edges removed.
    dotout_nr = create_dot_graph_nr(ordered_jobs, job_id_to_predecessors, job_id_to_successors)
    File.open("#{self.name.underscore}_nr.dot","w") { |fh| fh.write(dotout_nr) } # for debugging

    # -----------------------------------------------------------------
    # Create one Cbrain::PsomSubtask for each job
    # -----------------------------------------------------------------

    # At this point, ordered_jobs has them all ordered topologically
    pipe_run_dir = self.pipeline_run_dir
    safe_mkdir(pipe_run_dir)
    job_id_to_task = {}
    ordered_jobs.each_with_index do |job,job_idx|
      job_id    = job['id']
      job_name  = job['name']
      job_file  = job['job_file']
      job_level = job_id_to_level[job_id]

      # Create the task associated to one PSOM job
      subtask = CbrainTask::PsomSubtask.new(
        :status         => "Standby", # important! Will be changed to New only of everything OK, at the end.
        :user_id        => self.user_id,
        :group_id       => self.group_id,
        :bourreau_id    => self.bourreau_id,
        :tool_config_id => self.tool_config_id, # TODO this is not exactly right
        :description    => "Subtask ##{job_idx+1}/#{ordered_jobs.size} for #{fmri_study.name}\n\n#{job_name}",
        :launch_time    => self.launch_time,
        :run_number     => self.run_number,
        :share_wd_tid   => self.id,
        :rank           => job_idx + 1,
        :level          => job_level,
        :params         => {
          :psom_job_id            => job_id,
          :psom_job_name          => job_name,
          :psom_pipe_desc_subdir  => pipe_desc_dir,  # rel path of file to run is psom_pipe_desc_subdir/job_file
          :psom_job_script        => job_file,
          :psom_job_run_subdir    => pipe_run_dir,    # work directory for subtask; shared by all, here.
          :psom_ordered_idx       => job_idx,
          :psom_predecessor_tids  => [],
          :psom_successor_tids    => [],
          :psom_main_pipeline_tid => self.id # same as share_wd_tid
        }
      )
      job_id_to_task[job_id] = subtask

      #puts_blue "#{show_ids(job_id)} -> Creating subtasks"
      #puts_cyan " => PREC: #{show_ids(job_id_to_predecessors[job_id] || [])}"
      #puts_cyan " => SUCC: #{show_ids(job_id_to_successors[job_id] || [])}"

      # Add prerequisites so that it only runs when its
      # predecessors are done
      predecessor_ids = job_id_to_predecessors[job_id] || []
      predecessor_ids.each do |predecessor_id|
        prec_task = job_id_to_task[predecessor_id]
        cb_error "Can't find predecessor task '#{predecessor_id}' for '#{job_id}' ?!?" unless prec_task
        subtask.add_prerequisites_for_setup(prec_task, "Completed")
      end

      # Save it, in STANDBY state!
      # The tasks will be activated in cluster_commands().
      subtask.save!
      subtasks << subtask
    end

    # Now that all the subtasks have IDs, adjust them to
    # include their lists of predecessors and successors task IDs.
    subtasks.each do |subtask|
      subtask_params  = subtask.params
      subtask_job_id  = subtask_params[:psom_job_id]
      predecessor_ids = job_id_to_predecessors[subtask_job_id] || []
      successor_ids   = job_id_to_successors[subtask_job_id]   || []
      subtask.params[:psom_predecessor_tids] = predecessor_ids.map { |jid| job_id_to_task[jid].id }
      subtask.params[:psom_successor_tids]   = successor_ids.map   { |jid| job_id_to_task[jid].id }
      # Label the task with one or several graph node type keywords.
      prec_size = subtask.params[:psom_predecessor_tids].size
      succ_size = subtask.params[:psom_successor_tids].size
      gkeywords = []
      gkeywords << 'Initial'    if prec_size == 0
      gkeywords << 'PrecSerial' if prec_size == 1
      gkeywords << 'MultiPrec'  if prec_size  > 1
      gkeywords << 'Final'      if succ_size == 0
      gkeywords << 'SuccSerial' if succ_size == 1
      gkeywords << 'MultiSucc'  if succ_size  > 1
      subtask.params[:psom_graph_keywords] = gkeywords.join('-')
      subtask.save!
    end

    self.addlog("Created #{subtasks.size} PsomSubtasks")

    # Meta-graph: replace subtasks with a mixed set of Parallelizers,
    # Serializer and subtasks.
    self.save!
    metasubtasks = []
    if params[:generate_meta_graph] == "1"
      metasubtasks,num_serializers_par = self.build_meta_graph_tasks(subtasks)
      klass_cnt = metasubtasks.hashed_partitions { |t| t.name }
      report    = klass_cnt.keys.sort.map { |s| "#{klass_cnt[s].size} x #{s}" }.join(", ")
      ser_rep   = num_serializers_par > 0 ? ", with underneath #{num_serializers_par} x CbSerializer" : ""
      self.addlog("Created MetaTask graph: #{report}#{ser_rep}")
    end

    # Add prerequisites such that OUR post processing occurs only when
    # all final subtasks are done.
    subtasks.each do |subtask|
      next unless subtask.params[:psom_graph_keywords] =~ /Final/
      self.add_prerequisites_for_post_processing(subtask, "Completed")
    end

    self.save!

    return true

  # Handle errors
  rescue => ex
    # Cleanup subtasks
    subtasks.each do |badtask|
      badtask.destroy rescue true
    end
    raise ex
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params       = self.params || {}

    # Activate all the standby subtasks now
    self.psom_subtasks.all.each do |subtask|
      next unless subtask.status == "Standby" # in recover situations, they can be in other states.
      subtask.status = "New"
      subtask.save!
    end

    return nil # no cluster commands to run
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    cb_error "The PSOM pipeline coder did not implement save_results in his subclass!?!"
  end

  # Subclasses of PsomPipelineLauncher need to define
  # this method to return a XML document as a string
  # potentially with ERB (embedded ruby components).
  # The ERB code can user three local variables that
  # will be defined when the XML is being rendered:
  #
  #  * task       is self
  #  * params     is task.params
  #  * fmri_study is the input study object
  #
  # The default behavior is actually to try to find a file
  # in the subdirectory named 'models/cbrain_task/{underscored_class}/bourreau'
  # that has the same name as the class (underscored)
  # with a .xml.erb extension.
  def get_psom_launcher_template_xml
    plain_name     = self.name.underscore
    xml_base_name  = plain_name + ".xml.erb"
    full_path      = "#{Rails.root.to_s}/cbrain_plugins/cbrain_task/#{plain_name}/bourreau/#{xml_base_name}"
    if File.exists?(full_path)
      return File.read(full_path)
    end
    cb_error "XML template not found: '#{full_path}'"
  end

  # This method invokes whatever program is needed
  # to read the +xml_file+ supplied in argument and create
  # in +pipeline_dir+ the necessary PSOM files to describe
  # the subtasks involved in the pipeline.
  #
  # The default is to invoke the program that has the same
  # name as the class (underscored), providing it with the path
  # to the +xml_file+ and the +pipeline_dir+.
  def build_pipeline(xml_file, pipeline_dir)
    prog    = self.name.underscore
    # Note that 'psom_octave_wrapper.sh' is supplied in vendor/cbrain/bin on the Bourreau side
    command = "psom_octave_wrapper.sh $PSOM_ROOT/#{prog} #{xml_file} #{pipeline_dir}"
    self.addlog("Pipeline builder: #{command}")
    outs    = tool_config_system(command)
    stdout  = outs[0] ; stderr = outs[1]
    unless stdout.index("***Success***")
      self.addlog("Pipeline builder failed.")
      self.addlog("STDOUT:\n#{stdout}\n") unless stdout.blank?
      self.addlog("STDERR:\n#{stderr}\n") unless stderr.blank?
      return false
    end
    true
  end



  #--------------------------------------------------------------------
  # Overridable filesystem names
  #--------------------------------------------------------------------

  # Returns the basename for the subdirectory where the PSOM
  # pipeline description will be built.
  def pipeline_desc_dir #:nodoc:
    "pipeline_description"
  end

  # Returns the basename for the subdirectory where the PSOM
  # pipeline will actually be run.
  def pipeline_run_dir #:nodoc:
    "psom_pipeline"
  end



  #--------------------------------------------------------------------
  # Restart support methods
  #--------------------------------------------------------------------

  # Chronological behavior:
  #  - all subtasks reset here at Standby
  #  - setup() called:
  #     - pipeline description will be rebuilt in it
  #     - subtasks are NOT recreated in it (skipped by code that detect restarts)
  #  - cluster_command() called:
  #     - subtasks changed to New
  def restart_at_setup #:nodoc:
    params       = self.params || {}

    num_subtasks      = self.psom_subtasks.count
    comp_subtasks     = self.psom_subtasks.where( :status => "Completed" ).all
    if comp_subtasks.size != num_subtasks
      self.addlog("Cannot restart: cannot find all Completed subtasks we expected.")
      return false
    end

    comp_subtasks.each do |subtask|
      subtask.status = 'Standby'
      subtask.save
    end

    true
  end

  # Chronological behavior:
  #  - all subtasks reset here at Standby
  #  - cluster_command() called:
  #     - subtasks changed to New
  def restart_at_cluster #:nodoc:
    self.restart_at_setup # same logic
  end

  def restart_at_post_processing #:nodoc:
    false # Needs to be enabled in subclasses, if needed.
  end



  #--------------------------------------------------------------------
  # Error recovery support methods
  #--------------------------------------------------------------------

  def recover_from_setup_failure #:nodoc:
    params       = self.params || {}

    self.addlog("Cleaning up as part of recovery preparations")

    psom_subtasks.destroy_all
    
    pipe_run_dir  = self.pipeline_run_dir
    pipe_desc_dir = self.pipeline_desc_dir
    FileUtils.remove_dir(pipe_run_dir,  true) rescue true
    FileUtils.remove_dir(pipe_desc_dir, true) rescue true

    self.prerequisites = {}
    self.save
    true
  end

  def recover_from_cluster_failure #:nodoc:
    params       = self.params || {}

    self.addlog("Preparing to recover failed subtasks")

    subtasks     = self.psom_subtasks.all
    subtasks.each do |subtask|
      next unless subtask.status =~ /^Fail/
      subtask.recover
      subtask.save
    end
    true
  end

  def recover_from_post_processing_failure #:nodoc:
    false # Needs to be enabled in subclasses, if needed.
  end



  #--------------------------------------------------------------------
  # Graph Optimization Support Code
  #--------------------------------------------------------------------

  # Returns a NEW set of subtasks that group
  # together (reduce) the original set. We serialize blocks
  # of tasks that are linear and parallelize width-first
  # the task graph. Returns the set of tasks that
  # together implements the reduced graph.
  def build_meta_graph_tasks(subtasks) #:nodoc:

    by_id = subtasks.index_by &:id

    new_subtasks         = [] # declared early so it can be used in method's rescue clause
    fully_processed_tids = {} # PsomSubtask IDs only
    num_serializers_par  = 0  # number of CbSerializers under control of Parallelizers
    parallel_group_size  = (self.tool_config && self.tool_config.ncpus && self.tool_config.ncpus > 1) ? self.tool_config.ncpus : 2

    current_cut          = subtasks.select { |t| t.params[:psom_graph_keywords] =~ /Initial/ } # [t-1,t-2,t-3,t-4,t-5,t-6]

    # The cut progresses through the graph width-first,
    # starting at the inputs. Each cut is implemented by a set
    # of Parallelizer task plus some leftover CbSerial or individual
    # PsomTask. There are no prerequisites added to any of the
    # new tasks in this meta graph, as the ones from the PsomSubtask
    # are enough to enusre proper meta task ordering.
    while current_cut.size > 0

      # Extend the current cut to an array of single tasks plus Serializers for groups of serial tasks
      serialized_cut = current_cut.map do |task|
        sertask = self.serialize_task_at(task, by_id, fully_processed_tids) # [ S(t-1,t-2,t-3), t-4, S(t-5,t-6) ]
        num_serializers_par += 1 if sertask.is_a?(CbrainTask::CbSerializer) # may be adjusted by -1 below
        sertask
      end 

      # Create the parallelizers, and/or non-parallelized tasks too.
      triplet = CbrainTask::Parallelizer.create_from_task_list( serialized_cut,
                  :group_size               => parallel_group_size,
                  # :subtask_start_state      => "Standby",
                  # :parallelizer_start_state => "Standby",
                  :parallelizer_level       => 0
                ) do |paral, paral_subtasks|
        psom_idx = paral_subtasks.map { |t| t.is_a?(CbrainTask::PsomSubtask) ? (t.params[:psom_ordered_idx]+1).to_s : t.description }
        paral.description = psom_idx.join(" | ")
        paral.share_wd_tid = self.id # use the same workdir as the rest of the pipeline
        paral_subtasks.each do |t|
          #paral.rank  = t.rank      if t.rank  >= paral.rank
          paral.rank  = 0 # it looks better when they are all at the top of th batch
          paral.level = t.level     if t.level >= paral.level
        end
        paral.save!
      end

      messages          = triplet[0] # ignored
      parallelizer_list = triplet[1] # 0, 1 or many, each a P(S(),S(),t-n,S(),...)
      normal_list       = triplet[2] # 0, 1 or many, each a t-n or a S(t-n,t-n,...)

      new_subtasks += parallelizer_list
      new_subtasks += normal_list
      normal_list.each { |t| num_serializers_par -= 1 if t.is_a?(CbrainTask::CbSerializer) } # there are not parallelized

      # Unblock all the serializers in the non-parallelized list
      normal_list.each do |task|
        next unless task.is_a?(CbrainTask::CbSerializer)
        task.status = 'New'
        task.save!
      end

      # Flatten current cut and mark all its tasks as processed
      psom_flat_list = serialized_cut.inject([]) do |flat,task|
        flat << task                  if task.is_a?(CbrainTask::PsomSubtask)
        flat += task.enabled_subtasks if task.is_a?(CbrainTask::CbSerializer)
        flat
      end
      current_flat_ids = psom_flat_list.index_by &:id
      psom_flat_list.each { |task| fully_processed_tids[task.id] = true }

      # Compute next cut
      next_cut_tasks_by_id = {}
      psom_flat_list.each do |task|
        succ_ids = task.params[:psom_successor_tids].each do |succ_id|
          next if current_flat_ids[succ_id.to_i]
          succ = by_id[succ_id.to_i]
          succ_prec_ids = succ.params[:psom_predecessor_tids]
          next unless succ_prec_ids.all? { |tid| fully_processed_tids[tid.to_i] }
          next_cut_tasks_by_id[succ_id] ||= by_id[succ_id]
        end
      end
      current_cut = next_cut_tasks_by_id.values

    end
    
    return [ new_subtasks, num_serializers_par ]

  rescue => ex
    new_subtasks.each { |t| t.destroy rescue true }
    raise ex
  end

  # Starting with +task+, create and return a CbSerializer
  # that will execute it and its direct serial followers.
  # If +task+ is alone, return only +task+ itself. Whatever
  # is returned is in Standby mode.
  #
  # As a side effect, when N subtasks are serialized, the
  # subtasks numbered 1..N-1 (i.e. all but the first) are
  # immediately setup and configured. This is unavoidable
  # because otherwise their task prerequisites would prevent
  # the whole thing from ever starting in the first place.
  def serialize_task_at(task, by_id, fully_processed_tids) #:nodoc:
    task_list  = [ task ]
    serial_ids = { task.id => true }
    serializer = nil # declared here for methods's rescue clause

    # Find the longest line of tasks that are all chained together
    while true
      endoflist = task_list[-1]
      prop      = endoflist.params[:psom_graph_keywords] || ""
      break unless prop =~ /SuccSerial/
      succids   = endoflist.params[:psom_successor_tids] # should have single entry in it
      succid    = succids[0].to_i
      succ      = by_id[succid]
      succ_prec_ids = succ.params[:psom_predecessor_tids]
      break unless succ_prec_ids.all? { |tid| serial_ids[tid.to_i] || fully_processed_tids[tid.to_i] }
      task_list << succ
      serial_ids[succ.id] = true
    end

    return task if task_list.size <= 1

    # Create a single CbSerializer task; the subtasks and
    # the serializer itself are specially modified in the DO block.
    triplet = CbrainTask::CbSerializer.create_from_task_list( task_list,
                :group_size               => task_list.size, # all of them, no matter how many!
                # :subtask_start_state      => "Standby", # ok with 'New' at this level
                :serializer_start_state   => "Standby",
                :serializer_level         => 0
              ) do |ser,ser_subtasks|
        psom_idx = ser_subtasks.map { |t| (t.params[:psom_ordered_idx] + 1).to_s || t.id.to_s }.sort
        ser.description = "(#{psom_idx.join("-")})"
        ser.share_wd_tid = self.id # use the same workdir as the rest of the pipeline
        ser_subtasks.each_with_index do |t,sidx|
          #ser.rank  = t.rank      if t.rank  >= ser.rank
          ser.rank  = 0 # it looks better when they are all at the top of th batc
          ser.level = t.level     if t.level >= ser.level
          if sidx > 0 # the first one must block in New, the others are set up
            t.status_transition!(t.status, "Setting Up") # normally, the bourreau worker does this...
            t.setup_and_submit_job  # ... and this too.
            t.save!
          end
        end
        ser.save!
    end
    messages        = triplet[0] # ignored
    serializer_list = triplet[1] # we expect only one
    normal_list     = triplet[2] # we expect none

    cb_error "Internal error: didn't get a single CbSerializer?"    unless serializer_list.size == 1
    cb_error "Internal error: got normal task afetr serialization?" unless normal_list.size     == 0

    serializer = serializer_list[0]

    return serializer

  rescue => ex
    if serializer
      serializer.destroy rescue true
    end
    raise ex
  end



  #--------------------------------------------------------------------
  # Debug support code.
  #--------------------------------------------------------------------

  private

  # Debug topological sort; pass it a job ID, an array of IDs,
  # an object that responds to ['id'] or an array of such objects.
  # Colorized the shortened IDs.
  def show_ids(idlist) #:nodoc:
     idlist = [ idlist ] unless idlist.is_a?(Array)
     res = ""
     idlist.each do |j|
       ji = j.is_a?(String) ? j : j['id']
       ji = ji.to_s
       ji = ("0" * (4-ji.size)) + ji if ji.size < 4
       p1 = ji[0,2]; p2 = ji[2,2]; name = p1+p2;
       v1 = 0; v2 = 0
       p1.each_byte { |x| v1 += x }
       p2.each_byte { |x| v2 += x }
       c1 = v1 % 8
       c2 = v2 % 8
       colname = "\e[3#{c1};4#{c2}m#{name}\e[0m"
       res += " " unless res.blank?
       res += colname
     end
     res
  end

  # Returns a graph of the PSOM jobs dependencies in DOT format
  def create_dot_graph(xml_hash) #:nodoc:
    jobs            = xml_hash['pipeline']['job']
    jobs            = [ jobs ] unless jobs.is_a?(Array)
    jobs_by_id      = jobs.index_by { |job| job['id'] }

    dotout = "digraph #{self.name} {\n"
    jobs.each do |job|
      job_id       = job['id']
      job_name     = job['name']
      dependencies = (job['dependencies'] || {})['dependency'] || []
      dependencies = [ dependencies] unless dependencies.is_a?(Array)
      dependencies.each do |prec_id|
        prec      = jobs_by_id[prec_id]
        prec_name = prec['name']
        dotout += "  #{prec_name} -> #{job_name};\n"
      end
    end
    dotout += "}\n"
    dotout
  end

  def remove_redundant_dependencies(before, after) #:nodoc:
    all_ids = (before.keys + after.keys).uniq
    all_ids.each do |job_id|
      succ_ids = after[job_id] || []
      redundant_succ_ids = {}
      succ_ids.each do |succ_id|
        other_succ_ids = succ_ids.reject { |i| i == succ_id }
        if other_succ_ids.any? { |i| all_succ_ids(i, after)[succ_id] } # if true, job_id -> succ_id is redundant
          redundant_succ_ids[succ_id] = true
        end
      end
      succ_ids.reject! { |succ_id| redundant_succ_ids[succ_id] }
      after[job_id] = succ_ids
      redundant_succ_ids.keys.each do |succ_id|
        bef_ids = before[succ_id].reject { |i| i == job_id }
        before[succ_id] = bef_ids
      end
    end
  end

  # Returns a graph of the PSOM jobs dependencies in DOT format
  # with redundant dependencies removed.
  #
  # Can be simplified to remove calls to all_succ_ids if
  # remove_redundant_dependencies() is ever implemented and
  # used (see commented-out code above)
  def create_dot_graph_nr(ordered_jobs, id_to_prec, id_to_succ) #:nodoc:
    dotout = "digraph #{self.name}_nr {\n"
    seen_job_ids = {}
    jobs_by_id   = ordered_jobs.index_by { |job| job['id'] }
    ordered_jobs.each do |job|
      job_id       = job['id']
      job_name     = job['name']
      prec_ids     = id_to_prec[job_id] || []
      succ_ids     = id_to_succ[job_id] || []
      seen_job_ids[job_id] = true
      succ_ids.each do |succ_id|
        other_succ_ids = succ_ids.reject { |i| i == succ_id }
        next if other_succ_ids.any? { |i| all_succ_ids(i,id_to_succ)[succ_id] }
        succ_job      = jobs_by_id[succ_id]
        succ_job_name = succ_job['name']
        dotout += "  #{job_name} -> #{succ_job_name};\n"
      end
    end
    dotout += "}\n"
    dotout
  end

  def all_succ_ids(id,id_to_succ) #:nodoc:
    @_all_succ_ids ||= {}
    return @_all_succ_ids[id] if @_all_succ_ids.has_key?(id)
    direct = id_to_succ[id] || []
    union  = {}
    direct.each do |sid|
      union[sid] = true
      asid = all_succ_ids(sid,id_to_succ)
      union.merge!(asid)
    end
    @_all_succ_ids[id] = union
    union
  end

end

