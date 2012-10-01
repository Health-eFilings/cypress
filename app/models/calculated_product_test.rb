class CalculatedProductTest < ProductTest

  state_machine :state do
    
    after_transition any => :generating_records do |test|
      min_set = PatientPopulation.min_coverage(test.measure_ids)
      p_ids = min_set[:minimal_set]

      #randomly pick a number of other patients to give to the vendor
      #p_ids << minimal_set[:overflow].pick some random peeps
      
      # do this synchronously because it does not take long
      pcj = Cypress::PopulationCloneJob.new("id", {'patient_ids' =>p_ids, 'test_id' => test.id})
      pcj.perform
      #now calculate the expected results
      test.calculate
    end
        
    after_transition any => :calculating_expected_results do |test|
      Cypress::MeasureEvaluationJob.create({"test_id" =>  test.id.to_s})
    end
        
    event :generate_population do
      transition :pending => :generating_records
    end
    
    event :calculate do
      transition :generating_records => :calculating_expected_results
    end
  
  end
  
  #after the test is created generate the population
  after_create :generate_population

  def expected_Results(mesasure_id) 
   (expected_results ||{})[measure_id]
  end


  

  def execute(params)

    qrda_file = params[:results]
    data = qrda_file.open.read
    reported_results = Cypress::QrdaUtility.extract_results(data)  
    qrda_errors = Cypress::QrdaUtility.validate_cat3(data)  
    
    validation_errors = []
    qrda_errors.each do |e|
      validation_errors << ExecutionError.new(message: e, msg_type: :warning)
    end

    expected_results.each_pair do |key,expected_result|
      reported_result = reported_results[key] || {}
      errs = []

      expected_result.each_pair do |component, value|
        if reported_result[component] != value
         errs << "expected #{component} value #{value} does not match reported value #{reported_result[component]}"
        end
      end
      if errs
        validation_errors << ExecutionError.new(message: errs.join(",  "), msg_type: :error, measure_id: key )
      end
    end    

    te = self.test_executions.build(expected_results:self.expected_results,  reported_results: reported_results, execution_errors: validation_errors)
    
    te.save
    ids = Cypress::ArtifactManager.save_artifacts(qrda_file,te)
    te.file_ids = ids
    te.save
    
    (te.execution_errors.where({msg_type: :error}).count == 0) ? te.pass : te.failed
    te
  end
  
  
  def self.product_type_measures
    Measure.top_level_by_type("ep")
  end
  
  
end
