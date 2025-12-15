require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Boiler_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  start_time = Time.now
  # Test to validate the boiler thermal efficiency generated against expected values.
  #  Makes use of the template design pattern with the work done by the do_* method below (i.e. 'do_' prepended to the current method name)
  def test_boiler
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = { TestMethod: __method__,
                        SaveIntermediateModels: true,
                        mau_type: true,
                        mau_heating_coil_type: 'Hot Water',
                        baseboard_type: 'Hot Water' }

    # Define test cases.
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { Reference: "NECB 2011 p3 Table 5.2.12.1, 8.4.4.10.(6) clauses b,c,d" }
    test_cases[:NECB2015] = { Reference: "NECB 2015 p1 Table 5.2.12.1, 8.4.4.9.(6) clauses b,c,d" }
    test_cases[:NECB2017] = { Reference: "NECB 2017 p2 Table 5.2.12.1, 8.4.4.9.(6) clauses b,c,d" }
    test_cases[:NECB2020] = { Reference: "NECB 2020 p1 Table 5.2.12.1.-N, 8.4.4.9.(6) clauses b,c,d" }

    # This test verifies three key aspects of the boiler system configuration:
    #   1. Boiler efficiency values – confirm that the calculated or assigned
    #      efficiency matches the expected performance metric (thermal, AFUE, or
    #      combustion efficiency).
    #   2. Number of boilers and their capacities – ensure the model applies
    #      NECB2011 rules for boiler sizing based on total heating capacity:
    #        - ≤ 176 kW  → one single-stage boiler
    #        - > 176 kW and ≤ 352 kW → two boilers of equal capacity
    #        - > 352 kW → one modulating boiler capable of operating down to 25% load
    #   3. Boiler performance curve coefficients – validate that the efficiency
    #      curve data (name, type, and coefficients) are correctly assigned to each
    #      boiler in the model.
    # These tests are executed for multiple fuel types:
    #   - Three cases for Natural Gas (NG) and Fuel Oil
    #   - One case for Electric boilers
    test_cases_hash = { vintage: @AllTemplates,
                        fuel_type: ["Electricity"],
                        TestCase: ["case-1"],
                        TestPars: { :tested_capacity_kW => 10.0,
                                    :efficiency_metric => "thermal efficiency" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: @AllTemplates,
                        fuel_type: ["NaturalGas", "FuelOilNo2"],
                        TestCase: ["Single_Small_Boiler"],
                        TestPars: { :name => "tbd",
                                    :tested_capacity_kW => 43.96,
                                    :efficiency_metric => "annual fuel utilization efficiency",
                                    :efficiency_value => "tbd" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { vintage: @AllTemplates,
                        fuel_type: ["NaturalGas", "FuelOilNo2"],
                        TestCase: ["Two_Equal_Sized_Boilers"],
                        TestPars: { :name => "tbd",
                                    :tested_capacity_kW => 264.0,
                                    :efficiency_metric => "thermal efficiency",
                                    :efficiency_value => "tbd" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = { vintage: @AllTemplates,
                        fuel_type: ["NaturalGas", "FuelOilNo2"],
                        TestCase: ["Single_Large_Boiler"],
                        TestPars: { :name => "tbd",
                                    :tested_capacity_kW => 2510,
                                    :efficiency_metric => "combustion efficiency",
                                    :efficiency_value => "tbd" } }
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
    msg = "Boiler efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_boiler_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_boiler(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:TestMethod]
    save_intermediate_models = test_pars[:SaveIntermediateModels]
    mau_type = test_pars[:mau_type]
    mau_heating_coil_type = test_pars[:mau_heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fuel_type = test_pars[:fuel_type]
    vintage = test_pars[:vintage]

    # Test specific inputs.
    boiler_cap = test_case[:tested_capacity_kW]
    efficiency_metric = test_case[:efficiency_metric]

    # Define the test name.
    name = "#{vintage}_sys1_Boiler-#{fuel_type}_cap-#{boiler_cap.to_int}kW_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
    name_short = "#{vintage}_sys1_Boiler-#{fuel_type}_cap-#{boiler_cap.to_int}kW"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    results = Hash.new

    # Wrap test in begin/rescue/ensure.
    begin
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      weather_file = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file)
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

      # Setup hot water loop
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)

      standard.setup_hw_loop_with_components(model, hw_loop, fuel_type, fuel_type, always_on)
      standard.add_sys1_unitary_ac_baseboard_heating(
        model: model,
        zones: model.getThermalZones,
        mau_type: mau_type,
        mau_heating_coil_type: mau_heating_coil_type,
        baseboard_type: baseboard_type,
        hw_loop: hw_loop
      )

      # Set boiler capacity and run sizing
      model.getBoilerHotWaters.each { |b| b.setNominalCapacity(boiler_cap * 1000.0) }
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

    rescue => e
      msg = "#{__FILE__}::#{__method__}\n#{e.full_message}"
      logger.error(msg)
      return { ERROR: msg }
    end

    # Extract efficiency value
    test_efficiency_value = model.getBoilerHotWaters.find { |boiler| boiler.nominalCapacity.to_f > 1 }&.nominalThermalEfficiency || 0

    case efficiency_metric
    when 'annual fuel utilization efficiency'
      test_efficiency_value = OpenstudioStandards::HVAC.thermal_eff_to_afue(test_efficiency_value)
    when 'combustion efficiency'
      test_efficiency_value = OpenstudioStandards::HVAC.thermal_eff_to_comb_eff(test_efficiency_value)
    end

    # Build results
    results = {
      name: name,
      tested_capacity_kW: boiler_cap.signif,
      efficiency_metric: efficiency_metric,
      efficiency_value: test_efficiency_value.signif
    }

    boilers = model.getBoilerHotWaters
                   .select { |boiler| boiler.nominalCapacity.to_f >= 0.1 }
                   .sort_by { |boiler| boiler.name.to_s.include?('Primary') ? 0 : 1 }

    total_capacity = boilers.sum { |boiler| boiler.nominalCapacity.to_f / 1000.0 }

    boilers.each_with_index do |boiler, i|
      eff_curve_name, eff_curve_type, corr_coeff = get_boiler_eff_curve_data(boiler)
      results["Boiler-#{i + 1}".to_sym] = {
        name: boiler.name.to_s,
        boiler_capacity_kW: (boiler.nominalCapacity.to_f / 1000.0).signif,
        minimum_part_load_ratio: boiler.minimumPartLoadRatio,
        eff_curve_name: eff_curve_name,
        eff_curve_type: eff_curve_type,
        curve_coefficients: corr_coeff
      }
    end

    results[:All] = {
      total_capacity_kW: total_capacity.signif,
      number_of_boilers: boilers.size
    }

    logger.info "Completed individual test: #{name}"
    results
  end

  # Test to validate the custom boiler thermal efficiencies applied against expected values stored in the file:
  # 'compliance_boiler_custom_efficiencies_expected_results.json
  def test_custom_efficiency
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all cases.
    test_parameters = { TestMethod: __method__,
                        SaveIntermediateModels: false,
                        mau_type: true,
                        mau_heating_coil_type: 'Hot Water',
                        baseboard_type: 'Hot Water' }

    # Define test cases.
    standard_ecms = get_standard("ECMS")
    boilers = standard_ecms.standards_data["tables"]["boiler_eff_ecm"]["table"] # Used to get the case names and data.
    test_cases = Hash.new
    boilers.each do |boiler|
      test_cases_hash = { vintage: @AllTemplates,
                          TestCase: [boiler["name"]],
                          TestPars: { :Reference => boiler["notes"],
                                      :boiler_name => boiler["name"],
                                      :boiler_eff => boiler["efficiency"],
                                      :eff_curve_name => boiler["part_load_curve"] } }
      new_test_cases = make_test_cases_json(test_cases_hash)
      merge_test_cases!(test_cases, new_test_cases)
    end

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
    msg = "Boiler efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_custom_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_custom_efficiency(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:TestMethod]
    save_intermediate_models = test_pars[:SaveIntermediateModels]
    mau_type = test_pars[:mau_type]
    mau_heating_coil_type = test_pars[:mau_heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    vintage = test_pars[:vintage]
    reference = test_case[:Reference]

    # Test specific inputs.
    boiler_name = test_case[:boiler_name]
    fuel_type = 'NaturalGas'
    boiler_cap = 1500000

    # Define the test name.
    name = "#{vintage}_sys1_Boiler-#{fuel_type}_cap-#{boiler_cap.to_int}W_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}_efficiency-#{boiler_name}"
    name_short = "#{vintage}_sys1-#{boiler_name}"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Started individual test: #{name}"
    results = Hash.new

    # Wrap test in begin/rescue/ensure.
    begin
      standard = get_standard(vintage)
      standard_ecms = get_standard("ECMS")

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, fuel_type, fuel_type, always_on)
      standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                     zones: model.getThermalZones,
                                                     mau_type: mau_type,
                                                     mau_heating_coil_type: mau_heating_coil_type,
                                                     baseboard_type: baseboard_type,
                                                     hw_loop: hw_loop)
      model.getBoilerHotWaters.each { |iboiler| iboiler.setNominalCapacity(boiler_cap) }

      # Run sizing.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

      # Customize the efficiency. Specify the name and the method will look up the correct boiler.
      standard_ecms.modify_boiler_efficiency(model: model, boiler_eff: boiler_name)
    rescue => error
      msg = "#{__FILE__}::#{__method__}\n#{error.full_message}"
      logger.error(msg)
      return { ERROR: msg }
    end

    # Extract the results for checking. There are always two boilers.
    results[:Reference] = reference
    boilers = model.getBoilerHotWaters
    boilers.each do |boiler|
      eff_curve_name, eff_curve_type, corr_coeff = get_boiler_eff_curve_data(boiler)
      boiler_eff = boiler.nominalThermalEfficiency
      boiler_name = boiler.name.get
      results[boiler_name.to_sym] = {
        boiler_name: boiler_name,
        boiler_eff: boiler_eff,
        eff_curve_name: eff_curve_name,
        eff_curve_type: eff_curve_type,
        curve_coefficients: corr_coeff
      }
    end
    logger.info "Completed individual test: #{name}"
    return results
  end

  # @note Helper method to return the part load curve data.
  # @param boiler [OS::Boiler] an openstudio boiler.
  # @return the efficiency curve name [String], curve type [String] and the curve coefficients [Array] (curve type dependent).
  def get_boiler_eff_curve_data(boiler)
    corr_coeff = []
    eff_curve = nil
    eff_curve_type = boiler.normalizedBoilerEfficiencyCurve.get.iddObjectType.valueName.to_s
    case eff_curve_type
    when "OS_Curve_Bicubic"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBicubic.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.coefficient3xPOW2
      corr_coeff << eff_curve.coefficient4y
      corr_coeff << eff_curve.coefficient5yPOW2
      corr_coeff << eff_curve.coefficient6xTIMESY
      corr_coeff << eff_curve.coefficient7xPOW3
      corr_coeff << eff_curve.coefficient8yPOW3
      corr_coeff << eff_curve.coefficient9xPOW2TIMESY
      corr_coeff << eff_curve.coefficient10xTIMESYPOW2
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
      corr_coeff << eff_curve.minimumValueofy
      corr_coeff << eff_curve.maximumValueofy
    when "OS_Curve_Biquadratic"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBiquadratic.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.coefficient3xPOW2
      corr_coeff << eff_curve.coefficient4y
      corr_coeff << eff_curve.coefficient5yPOW2
      corr_coeff << eff_curve.coefficient6xTIMESY
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
      corr_coeff << eff_curve.minimumValueofy
      corr_coeff << eff_curve.maximumValueofy
    when "OS_Curve_Cubic"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.coefficient3xPOW2
      corr_coeff << eff_curve.coefficient4xPOW3
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
    when "OS_Curve_Linear"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveLinear.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
    when "OS_Curve_Quadratic"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadratic.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.coefficient3xPOW2
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
    when "OS_Curve_QuadraticLinear"
      eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadraticLinear.get
      corr_coeff << eff_curve.coefficient1Constant
      corr_coeff << eff_curve.coefficient2x
      corr_coeff << eff_curve.coefficient3xPOW2
      corr_coeff << eff_curve.coefficient4y
      corr_coeff << eff_curve.coefficient5xTIMESY
      corr_coeff << eff_curve.coefficient6xPOW2TIMESY
      corr_coeff << eff_curve.minimumValueofx
      corr_coeff << eff_curve.maximumValueofx
      corr_coeff << eff_curve.minimumValueofy
      corr_coeff << eff_curve.maximumValueofy
    end
    eff_curve_name = eff_curve.name.get
    return eff_curve_name, eff_curve_type, corr_coeff
  end

  # Prints the test durations
  end_time = Time.now
  puts "Total test time: #{(end_time - start_time) / 60} minutes"
end
