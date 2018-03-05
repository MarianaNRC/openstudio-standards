
class Standard
  # @!group Construction

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
  # @param target_u_value_ip [Double] U-Value (Btu/ft^2*hr*R)
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param target_includes_int_film_coefficients [Bool] if true, subtracts off standard film interior coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @param target_includes_ext_film_coefficients [Bool] if true, subtracts off standard exterior film coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @return [Bool] returns true if successful, false if not
  # @todo Put in Phlyroy's logic for inferring the insulation layer of a construction
  def construction_set_u_value(construction, target_u_value_ip, insulation_layer_name = nil, intended_surface_type = 'ExteriorWall', target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    if construction.isFenestration
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ConstructionBase', "Can only set the u-value of opaque constructions or simple glazing. #{construction.name} is not opaque or simple glazing.")
      return false
    end

    # Make sure an insulation layer was specified
    if insulation_layer_name.nil? && target_u_value_ip == 0.0
      # Do nothing if the construction already doesn't have an insulation layer
    elsif insulation_layer_name.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ConstructionBase', "Requested U-value of #{target_u_value_ip} for #{construction.name}, but this construction has no insulation layer specified.  Requested U-value will not be set.")
      return false
    end

    # Remove the insulation layer if the specified U-value is zero.
    if target_u_value_ip == 0.0
      layer_index = 0
      construction.layers.each do |layer|
        break if layer.name.get == insulation_layer_name
        layer_index += 1
      end
      construction.eraseLayer(layer_index)
      return true
    end

    # Convert the target U-value to SI
    target_u_value_ip = target_u_value_ip.to_f
    target_r_value_ip = 1.0 / target_u_value_ip

    target_u_value_si = OpenStudio.convert(target_u_value_ip, 'Btu/ft^2*hr*R', 'W/m^2*K').get
    target_r_value_si = 1.0 / target_u_value_si

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "#{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_u_value_ip = #{target_u_value_ip.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_r_value_ip = #{target_r_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_u_value_si = #{target_u_value_si.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_r_value_si = #{target_r_value_si.round(2)} for #{construction.name}.")

    # Determine the R-value of the non-insulation layers
    other_layer_r_value_si = 0.0
    construction.layers.each do |layer|
      next if layer.to_OpaqueMaterial.empty?
      next if layer.name.get == insulation_layer_name
      other_layer_r_value_si += layer.to_OpaqueMaterial.get.thermalResistance
    end

    # Determine the R-value of the air films, if requested
    other_layer_r_value_si += film_coefficients_r_value(intended_surface_type, target_includes_int_film_coefficients, target_includes_ext_film_coefficients)

    # Determine the difference between the desired R-value
    # and the R-value of the non-insulation layers and air films.
    # This is the desired R-value of the insulation.
    ins_r_value_si = target_r_value_si - other_layer_r_value_si
    if ins_r_value_si <= 0.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ConstructionBase', "Requested U-value of #{target_u_value_ip} for #{construction.name} is too low given the other materials in the construction; insulation layer will not be modified.")
      return false
    end
    ins_r_value_ip = OpenStudio.convert(ins_r_value_si, 'm^2*K/W', 'ft^2*h*R/Btu').get

    # Set the R-value of the insulation layer
    construction.layers.each do |layer|
      next unless layer.name.get == insulation_layer_name
      if layer.to_StandardOpaqueMaterial.is_initialized
        layer = layer.to_StandardOpaqueMaterial.get
        layer.setThickness(ins_r_value_si * layer.getConductivity)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      elsif layer.to_MasslessOpaqueMaterial.is_initialized
        layer = layer.to_MasslessOpaqueMaterial.get
        layer.setThermalResistance(ins_r_value_si)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      elsif layer.to_AirGap.is_initialized
        layer = layer.to_AirGap.get
        target_thickness = ins_r_value_si * layer.thermalConductivity
        layer.setThickness(target_thickness)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      end
    end

    # Modify the construction name
    construction.setName("#{construction.name} R-#{target_r_value_ip.round(2)}")

    return true
  end

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
  # @param target_u_value_ip [Double] U-Value (Btu/ft^2*hr*R)
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param target_includes_int_film_coefficients [Bool] if true, subtracts off standard film interior coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @param target_includes_ext_film_coefficients [Bool] if true, subtracts off standard exterior film coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_u_value(construction, target_u_value_ip, intended_surface_type = 'ExteriorWall', target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ConstructionBase', "Can only set the u-value of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    # Convert the target U-value to SI
    target_u_value_ip = target_u_value_ip.to_f
    target_r_value_ip = 1.0 / target_u_value_ip

    target_u_value_si = OpenStudio.convert(target_u_value_ip, 'Btu/ft^2*hr*R', 'W/m^2*K').get
    target_r_value_si = 1.0 / target_u_value_si

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "#{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_u_value_ip = #{target_u_value_ip.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_r_value_ip = #{target_r_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_u_value_si = #{target_u_value_si.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "---target_r_value_si = #{target_r_value_si.round(2)} for #{construction.name}.")

    # Determine the R-value of the air films, if requested
    film_coeff_r_value_si = 0.0
    film_coeff_r_value_si += film_coefficients_r_value(intended_surface_type, target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    film_coeff_u_value_si = 1.0 / film_coeff_r_value_si
    film_coeff_u_value_ip = OpenStudio.convert(film_coeff_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get

    # Determine the difference between the desired R-value
    # and the R-value of the and air films.
    # This is the desired R-value of the insulation.
    ins_r_value_si = target_r_value_si - film_coeff_r_value_si
    if ins_r_value_si <= 0.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ConstructionBase', "Requested U-value of #{target_u_value_ip} for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)}; U-value will not be modified.")
      return false
    end
    ins_u_value_si = 1.0 / ins_r_value_si
    ins_u_value_ip = OpenStudio.convert(ins_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get

    # Set the U-value of the insulation layer
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setUFactor(ins_u_value_si)
    glass_layer.setName("#{glass_layer.name} U-#{ins_u_value_ip.round(2)}")

    # Modify the construction name
    construction.setName("#{construction.name} U-#{target_u_value_ip.round(2)}")

    return true
  end

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
  # @param target_shgc [Double] Solar Heat Gain Coefficient
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_shgc(construction, target_shgc)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ConstructionBase', "Setting SHGC for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ConstructionBase', "Can only set the SHGC of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    # Set the SHGC
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setSolarHeatGainCoefficient(target_shgc)
    glass_layer.setName("#{glass_layer.name} SHGC #{target_shgc.round(2)}")

    # Modify the construction name
    construction.setName("#{construction.name} SHGC #{target_shgc.round(2)}")

    return true
  end

  # Determines if the construction is a simple glazing construction,
  # as indicated by having a single layer of type SimpleGlazing.
  # @return [Bool] returns true if it is a simple glazing, false if not.
  def construction_simple_glazing?(construction)
    # Not simple if more than 1 layer
    if construction.layers.length > 1
      return false
    end

    # Not simple unless the layer is a SimpleGlazing material
    if construction.layers.first.to_SimpleGlazing.empty?
      return false
    end

    # If here, must be simple glazing
    return true
  end

  # Set the F-Factor of a slab to a specified value.
  # Assumes an unheated, fully insulated slab, and modifies
  # the insulation layer according to the values from 90.1-2004
  # Table A6.3 Assembly F-Factors for Slab-on-Grade Floors.
  #
  # @param target_f_factor_ip [Double] F-Factor
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @return [Bool] returns true if successful, false if not
  def construction_set_slab_f_factor(construction, target_f_factor_ip, insulation_layer_name = nil)
    # Regression from table A6.3 unheated, fully insulated slab
    r_value_ip = 1.0248 * target_f_factor_ip**-2.186
    u_value_ip = 1.0 / r_value_ip

    # Set the insulation U-value
    construction_set_u_value(construction, u_value_ip, insulation_layer_name, 'GroundContactFloor', true, true)

    # Modify the construction name
    construction.setName("#{construction.name} F-#{target_f_factor_ip.round(3)}")

    return true
  end

  # Set the C-Factor of an underground wall to a specified value.
  # Assumes continuous exterior insulation and modifies
  # the insulation layer according to the values from 90.1-2004
  # Table A4.2 Assembly C-Factors for Below-Grade walls.
  #
  # @param target_c_factor_ip [Double] C-Factor
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @return [Bool] returns true if successful, false if not
  def construction_set_underground_wall_c_factor(construction, target_c_factor_ip, insulation_layer_name = nil)
    # Regression from table A4.2 continuous exterior insulation
    r_value_ip = 0.775 * target_c_factor_ip**-1.067
    u_value_ip = 1.0 / r_value_ip

    # Set the insulation U-value
    construction_set_u_value(construction, u_value_ip, insulation_layer_name, 'GroundContactWall', true, true)

    # Modify the construction name
    construction.setName("#{construction.name} C-#{target_c_factor_ip.round(3)}")

    return true
  end

  # Get the SHGC as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  # @return [Double] the SHGC as a decimal.
  def construction_calculated_solar_heat_gain_coefficient(construction)
    construction_name = construction.name.get.to_s

    shgc = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Construction', "SHGC row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      shgc_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass SHGC'
                  AND RowName='#{row_id}'"

      shgc = sql.execAndReturnFirstDouble(shgc_query)

      shgc = if shgc.is_initialized
               shgc.get
             end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return shgc
  end

  # Get the VT as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  # @return [Double] the visible transmittance as a decimal.
  def construction_calculated_visible_transmittance(construction)
    construction_name = construction.name.get.to_s

    vt = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "VT row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      vt_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass Visible Transmittance'
                  AND RowName='#{row_id}'"

      vt = sql.execAndReturnFirstDouble(vt_query)

      vt = if vt.is_initialized
             vt.get
           end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Space', 'Model has no sql file containing results, cannot lookup data.')
    end

    return vt
  end

  # Get the U-Factor as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  # @return [Double] the U-Factor in W/m^2*K.
  def construction_calculated_u_factor(construction)
    construction_name = construction.name.get.to_s

    u_factor_w_per_m2_k = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Construction', "U-Factor row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      u_factor_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass U-Factor'
                  AND RowName='#{row_id}'"

      u_factor_w_per_m2_k = sql.execAndReturnFirstDouble(u_factor_query)

      u_factor_w_per_m2_k = if u_factor_w_per_m2_k.is_initialized
                              u_factor_w_per_m2_k.get
                            end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return u_factor_w_per_m2_k
  end
end
