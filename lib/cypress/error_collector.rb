module Cypress
  module ErrorCollector
    class FileNotFound < StandardError
    end

    def collected_errors(execution)
      # gonna return all the errors for this execution, structured in a reasonable way.
      collected_errors = { nonfile: get_nonfile_errors(execution), files: {} }
      execution.artifact.file_names.each do |this_name|
        all_errs = execution.execution_errors.by_file(this_name.force_encoding('UTF-8'))
        related_errs = execution.sibling_execution ? execution.sibling_execution.execution_errors.by_file(this_name) : [] # c3
        next unless (all_errs.count + related_errs.count).positive?

        doc = get_file(execution.artifact, this_name)
        collected_errors[:files][this_name] = create_file_error_hash(doc, all_errs, related_errs)
      end
      collected_errors
    rescue => e
      { nonfile: [], files: {}, exception: e }
    end

    # returns [file_name, error_result]
    def file_name_and_error_result_from_execution(execution)
      errs = collected_errors(execution)
      files = errs.files.select { |file_name, _| route_file_name(file_name) == params[:file_name] }
      file_name_and_error_result_from_files(files, params[:file_name])
    end

    def file_name_and_error_result_from_files(files, file_name)
      [files.first[0], files.first[1]]
    rescue
      raise Mongoid::Errors::DocumentNotFound.new FileNotFound, "could not find results for file #{file_name}"
    end

    private

    def get_file(artifact, file_name)
      data_to_doc(artifact.get_file(file_name))
    end

    def get_nonfile_errors(execution)
      messages1 = execution.execution_errors.by_file(nil).map(&:message)
      messages2 = execution.sibling_execution ? execution.sibling_execution.execution_errors.by_file(nil).map(&:message) : []

      (messages1 + messages2).uniq
    end

    def create_file_error_hash(doc, all_errs, related_errs)
      file_error_hash = {}
      file_error_hash['QRDA'] = error_hash(doc, all_errs.qrda_errors)
      file_error_hash['Reporting'] = error_hash(doc, all_errs.reporting_errors)
      file_error_hash['Submission'] = error_hash(doc, all_errs.submission_errors)
      file_error_hash['CMS Warnings'] = related_errs.count.positive? ? error_hash(doc, related_errs.only_cms_warnings) : { execution_errors: [] }
      file_error_hash['Other Warnings'] = related_errs.count.positive? ? error_hash(doc, related_errs.non_cms_warnings) : { execution_errors: [] }
      file_error_hash
    end

    def data_to_doc(data)
      if data.is_a? String
        Nokogiri::XML(data)
      else
        data
      end
    end

    def error_hash(doc, file_errors)
      return 0 unless file_errors.count

      error_map, error_attributes = match_xml_locations_to_error_ids(doc, file_errors)
      {
        doc: doc,
        execution_errors: file_errors,
        error_map: error_map,
        error_attributes: error_attributes
      }
    end

    # goes through each XML location and marks which errors that location is associated with
    def match_xml_locations_to_error_ids(doc, errors)
      uuid = UUID.new
      error_map = {}        # error_map[error_location] == xml_element_error_id
      error_attributes = [] # only gives error attribute if element has class Nokogiri::XML::Attr
      locations = errors.collect(&:location).compact

      locations.each do |location|
        # Get rid of some funky stuff generated by schematron
        clean_location = location.gsub("[namespace-uri()='urn:hl7-org:v3']", '')
        elem = doc.at_xpath(clean_location)
        next unless elem

        if elem.class == Nokogiri::XML::Attr
          error_attributes << elem
          elem = elem.element
        end
        error_map[location] = get_error_id(elem, uuid)
      end

      [error_map, error_attributes]
    end

    def get_error_id(element, uuid)
      element = element.root if node_type(element.type) == :document
      element['error_id'] = uuid.generate.to_s unless element['error_id']
      element['error_id']
    end

    NODE_TYPES = {
      1 => :element, 2 => :attribute, 3 => :text, 4 => :cdata, 5 => :ent_ref, 6 => :entity,
      7 => :instruction, 8 => :comment, 9 => :document, 10 => :doc_type, 11 => :doc_frag, 12 => :notaion
    }.freeze

    def node_type(type)
      NODE_TYPES[type]
    end
  end
end
