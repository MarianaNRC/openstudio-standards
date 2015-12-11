require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

class TestLargeOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['LargeOffice']
#  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
  templates = ['NECB 2011']
  #climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  climate_zones = ['NECB-CNEB-4']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestLargeOffice.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
