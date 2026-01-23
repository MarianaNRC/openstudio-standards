require 'minitest/unit'
require 'json'
require 'csv'
require 'digest'
require_relative '../../../helpers/necb_helper'

class NECBRegressionHelper < Minitest::Test
  include NecbHelper

  def setup
    @building_type = 'FullServiceRestaurant'
    @epw_file = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw'
    @template = 'NECB2011'
    @test_dir = "#{File.dirname(__FILE__)}/output"
    @expected_results_folder = "#{File.dirname(__FILE__)}/../expected/"
    @model = nil
    @model_name = nil
    @run_simulation = false
    @model_save = false
    @primary_heating_fuel = 'Electricity'
  end

  def create_model_and_regression_test(building_type: @building_type,
                                       epw_file: @epw_file,
                                       template: @template,
                                       test_dir: @test_dir,
                                       expected_results_folder: @expected_results_folder,
                                       run_simulation: @run_simulation,
                                       model_save: @model_save,
                                       primary_heating_fuel: @primary_heating_fuel)

    @building_type = building_type
    @epw_file = epw_file
    @template = template
    @primary_heating_fuel = primary_heating_fuel
    @expected_results_folder = expected_results_folder
    @test_dir = test_dir

    @model_name = "#{@building_type}-#{@template}-#{@primary_heating_fuel}-#{File.basename(@epw_file, '.epw').split('.')[0]}"
    @run_dir = File.join(@test_dir, @model_name)
    FileUtils.mkdir_p(@run_dir)

    standard = get_standard(@template)
    @model = standard.model_create_prototype_model(epw_file: @epw_file,
                                                   sizing_run_dir: @run_dir,
                                                   template: @template,
                                                   building_type: @building_type,
                                                   primary_heating_fuel: @primary_heating_fuel)

    unless @model.instance_of?(OpenStudio::Model::Model)
      logger.error("Model creation failed for #{@model_name}")
      return false, { "error" => "Model creation failed" }
    end

    logger.info("Model created successfully: #{@model_name}")

    # Run regression comparison
    result, diff = osm_regression(expected_results_folder: @expected_results_folder)
    if run_simulation
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path(@epw_file)
      OpenstudioStandards::Weather.model_set_building_location(@model, weather_file_path: weather_file_path)
      standard.model_run_simulation_and_log_errors(@model, @run_dir)
      logger.info("Full EnergyPlus simulation completed for #{@model_name}")
    end
    return result, diff
  end

  def osm_regression(expected_results_folder: @expected_results_folder)
    begin
      diffs = []
      # Create the diff folder (needed for regression results)
      diff_results_folder = File.join(File.expand_path('..', expected_results_folder), 'output_diff')
      FileUtils.mkdir_p(diff_results_folder) unless Dir.exist?(diff_results_folder)
      diff_file = File.join(diff_results_folder, "#{@model_name}_diffs.json")

      # Only create OSM/IDF folders if model_save is true
      if @model_save
        osm_results_folder = File.join(File.expand_path('..', expected_results_folder), 'output_osm')
        idf_results_folder = File.join(File.expand_path('..', expected_results_folder), 'output_idf')

        [osm_results_folder, idf_results_folder].each do |folder|
          FileUtils.mkdir_p(folder) unless Dir.exist?(folder)
        end

        test_osm_file = File.join(osm_results_folder, @model_name + '.osm')
        test_idf_file = File.join(idf_results_folder, @model_name + '.idf')

        BTAP::FileIO.save_osm(@model, test_osm_file)
        logger.info("Saved test result OSM file to #{test_osm_file}")

        BTAP::FileIO.save_idf(@model, test_idf_file)
        logger.info("Saved test result IDF file to #{test_idf_file}")
      else
        logger.info("Skipping OSM/IDF save for #{@model_name} (model_save = false)")
      end

      expected_osm_file = File.join(expected_results_folder, @model_name + '.osm')
      # Load expected OSM
      unless File.exist?(expected_osm_file)
        raise("Expected OSM path does not exist: #{expected_osm_file}")
      end
      expected_osm_model_path = OpenStudio::Path.new(expected_osm_file.to_s)
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      expected_model = version_translator.loadModel(expected_osm_model_path).get

      # Compare models
      diffs = BTAP::FileIO.compare_osm_files(expected_model, @model)
    rescue => exception
      error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})"
      exception.backtrace.drop(1).map { |s| "\n#{s}" }.each { |bt| error << bt.to_s }
      diffs << "#{@model_name}: Error \n#{error}"
    end

    # Write diff or error message
    FileUtils.rm(diff_file) if File.exist?(diff_file)
    if diffs.size > 0
      File.write(diff_file, JSON.pretty_generate(diffs))
      logger.warn("There were #{diffs.size} differences/errors in #{expected_osm_file} #{@template} #{@epw_file}")
      return false, { "diffs-errors" => diffs }
    else
      logger.info("No differences found for #{@model_name}")
      return true, []
    end
  end
end
