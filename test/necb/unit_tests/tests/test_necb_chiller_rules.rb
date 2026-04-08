require 'simplecov'
require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Chiller_Test < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  def test_NECB_chiller
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = { TestMethod: __method__,
                        SaveIntermediateModels: false,
                        fuel_type: 'Electricity',
                        mau_cooling_type: 'Hydronic' }

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { Reference: "NECB 2011 p3 Table 5.2.12.1. Points to CSA-C743-09, 8.4.4.11.(6), Table 8.4.4.22.C" }
    test_cases[:NECB2015] = { Reference: "NECB 2015 p1 Table 5.2.12.1. Points to CSA-C743-09, 8.4.4.10.(6), Table 8.4.4.21.C" }
    test_cases[:NECB2017] = { Reference: "NECB 2017 p2 Table 5.2.12.1. Points to CSA-C743-09, 8.4.4.10.(6), Table 8.4.4.21.C" }
    test_cases[:NECB2020] = { Reference: "NECB 2020 p1 Table 5.2.12.1.-K (Path B), 8.4.4.10.(6), Table 8.4.5.5" }

    # This test verifies three key aspects of the chiller system:
    #   1. Chiller efficiency — confirms that each chiller’s performance (COP and
    #      curve-based efficiency) matches expected standards.
    #
    #   2. Number of chillers and their capacities — ensures the model applies the
    #      NECB2011 rules for chiller sizing based on total cooling capacity:
    #         - ≤ 2100 kW → one chiller
    #         - > 2100 kW → two chillers, each sized at half the total capacity
    #
    #   3. Performance curve parameters — validates that the correct efficiency
    #      curve name, type, and coefficients are applied to each chiller.

    # Test cases. Define each case seperately as they have unique kW values to test across the vintages/chiller types.
    test_cases_hash = { vintage: ['NECB2011', 'NECB2015', 'NECB2017', 'NECB2020'],
                        chiller_type: ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                        TestCase: ["small-single"],
                        TestPars: { :tested_capacity_kW => 132 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: ['NECB2011', 'NECB2015', 'NECB2017', 'NECB2020'],
                        chiller_type: ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                        TestCase: ["medium-single"],
                        TestPars: { :tested_capacity_kW => 396 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: ['NECB2011', 'NECB2015', 'NECB2017', 'NECB2020'],
                        chiller_type: ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                        TestCase: ["large-single"],
                        TestPars: { :tested_capacity_kW => 791 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: ['NECB2011', 'NECB2015', 'NECB2017', 'NECB2020'],
                        chiller_type: ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                        TestCase: ["x-large-single"],
                        TestPars: { :tested_capacity_kW => 1200 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: ['NECB2020'],
                        chiller_type: ["Scroll", "Rotary Screw", "Reciprocating"],
                        TestCase: ["xx-large-twin"],
                        TestPars: { :tested_capacity_kW => 2200 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    file_root = "#{self.class.name}-#{__method__}".downcase
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Read expected results. 
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })

    # Check if test results match expected.
    msg = "Chiller COP test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_NECB_chiller_cop that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_NECB_chiller(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:TestMethod]
    save_intermediate_models = test_pars[:SaveIntermediateModels]
    mau_cooling_type = test_pars[:mau_cooling_type]
    fuel_type = test_pars[:fuel_type]
    vintage = test_pars[:vintage]
    chiller_type = test_pars[:chiller_type]

    # Test specific inputs.
    chiller_cap = test_case[:tested_capacity_kW]

    # Define the test name. 
    name = "#{vintage}_sys2_ChillerType-#{chiller_type}_Chiller_cap-#{chiller_cap}kW"
    name_short = "#{vintage}_sys2_Chiller-#{chiller_type}_cap-#{chiller_cap}kW"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"

    # Wrap test in begin/rescue/ensure.
    begin
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)
      standard.fuel_type_set = SystemFuels.new()
      standard.fuel_type_set.set_defaults(standards_data: standard.standards_data, primary_heating_fuel: fuel_type)
      standard.setup_hw_loop_with_components(model, hw_loop, fuel_type, fuel_type, always_on)
      standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                       zones: model.getThermalZones,
                                       chiller_type: chiller_type,
                                       fan_coil_type: 'FPFC',
                                       mau_cooling_type: mau_cooling_type,
                                       hw_loop: hw_loop)
      model.getChillerElectricEIRs.each { |chiller| chiller.setReferenceCapacity(chiller_cap * 1000.0) }

      # Run sizing.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    rescue => error
      msg = "#{__FILE__}::#{__method__}\n#{error.full_message}"
      logger.error(msg)
      return { ERROR: msg }
    end

    # Recover the COP for checking. 
    results = {}
    total_capacity = 0.0

    # Chillers whose names include "Primary" are given sort order 0, so Primary chillers are added first in the hash.
    chillers = model.getChillerElectricEIRs
                    .select { |c| c.referenceCapacity.to_f >= 0.1 }
                    .sort_by { |c| c.name.to_s.include?('Primary') ? 0 : 1 }

    chillers.each_with_index do |chiller, index|
      chiller_capacity = chiller.referenceCapacity.to_f / 1000.0
      total_capacity += chiller_capacity

      eff_curve = nil
      curve_data = nil

      eff_curve = chiller.coolingCapacityFunctionOfTemperature

      if eff_curve
        curve_data = get_curve_info(eff_curve)
      end

      chiller_id = "Chiller-#{index + 1}"

      results[chiller_id.to_sym] = {
        name: chiller.name.to_s,
        capacity_kW: chiller_capacity.signif(3),
        capacity_ton: OpenStudio.convert(chiller_capacity, 'kW', 'ton').get.signif,
        capacity_BTUh: OpenStudio.convert(chiller_capacity, 'kW', 'kBtu/hr').get.signif,
        COP_kW_kW: chiller.referenceCOP.to_f.signif(3),
        COP_kW_ton: OpenStudio.convert((1.0 / chiller.referenceCOP.to_f), '1/kW', '1/ton').get.signif,
        minimum_part_load_ratio: chiller.minimumPartLoadRatio.signif(3),
        curve_info: curve_data
      }
    end

    results[:All] = {
      tested_capacity_kW: chiller_cap.to_f.signif(3),
      total_capacity_kW: total_capacity.signif(3),
      number_of_chillers: chillers.size
    }
    logger.info "Completed test: #{name}"
    return results
  end
end
