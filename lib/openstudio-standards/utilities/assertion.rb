# PRM generation custom Error
class PRMError < StandardError
end

# PRM assertion method
# Raise assertion if the test (bool) is failed
#
# Before raise the exception, the method will generate the prm.log for debugging
# @param bool [Boolean, Object] an object for truthy evaluation
# @param log_dir [String] log file directory
# @param log_msg [String] message add to the log
# @param err_msg [String] message raise the exception
def prm_raise(bool, log_dir, log_msg, err_msg)
  unless bool
    OpenStudio.logFree(OpenStudio::Debug, 'prm.log', log_msg)
    log_messages_to_file_prm("#{log_dir}/prm.log", true)
    raise PRMError, err_msg
  end
end

# PRM reading function reads user data from a hash map.
# Handles key existence, value is nil and value string is empty
# @param user_data [Hash] a hash contains a user data
# @param key [String] key string
# @param default [Object] values assigned if the data is not available.
def prm_read_user_data(user_data, key, default = nil)
  return user_data.key?(key) && !user_data[key].nil && !user_data[key].to_s.empty? ? user_data[key] : default
end

# PRM get an additional property from an OpenStudio object as a boolean,
# if no such additional property, then return default value.
# @param component [OpenStudio object] the component to get the additional property from
# @param key [String] key string
# @param default [Boolean] the default to return when there is no matching key
def get_additional_property_as_boolean(component, key, default = false)
  value = default
  if component.additionalProperties.getFeatureAsBoolean(key).is_initialized
    value = component.additionalProperties.getFeatureAsBoolean(key).get
  else
    OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "Cannot find the #{key} in component: #{component.name.get}, default value #{default} is used.")
  end
  return value
end

# PRM get an additional property from an OpenStudio object as a double,
# if no such additional property, then return default value.
# @param component [OpenStudio object] the component to get the additional property from
# @param key [String] key string
# @param default [Boolean] the default to return when there is no matching key
def get_additional_property_as_double(component, key, default = 0.0)
  value = default
  if component.additionalProperties.getFeatureAsDouble(key).is_initialized
    value = component.additionalProperties.getFeatureAsDouble(key).get
  else
    OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "Cannot find the #{key} in component: #{component.name.get}, default value #{default} is used.")
  end
  return value
end
