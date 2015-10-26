require 'test_helper'

class PatientPopulationTest < ActiveSupport::TestCase
  setup do
    collection_fixtures('patient_populations', '_id')
  end

  test 'Should return installed patient populations' do
    populations = PatientPopulation.installed

    assert populations[0]._id.to_s == '4f57a52b1d41c851cf000001'
    assert populations[1]._id.to_s == '4f57a52b1d41c851cf000002'
  end
end
