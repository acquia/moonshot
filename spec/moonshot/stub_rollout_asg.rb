class StubRolloutASG
  InstanceSpec = Struct.new(:id, :conforming)

  attr_accessor :max, :desired
  attr_reader :instances

  def initialize
    @max = 3
    @desired = 2
    @instances = []
    @replacement_instances = []
    @instance_healths = {}
  end

  # Test config methods
  def add_instances(*instances)
    instances.each { |i| @instances << InstanceSpec.new(*i) }
  end

  def add_replacement_instances(*instances)
    instances.each { |i| @replacement_instances << InstanceSpec.new(*i) }
  end

  def add_health_response(id, *healths)
    @instance_healths[id] ||= []

    healths.each do |h|
      @instance_healths[id] << Moonshot::Tools::ASGRollout::InstanceHealth.new(*h)
    end
  end

  def everything_used?
    # All replacement instances were returned.
    @replacement_instances.empty? &&
      # And all health queries were returned.
      @instance_healths.all? { |_, v| v.empty? }
  end

  # Implementation methods
  def current_max_and_desired
    [@max, @desired]
  end

  def set_max_and_desired(max, desired)
    @max = max
    @desired = desired
  end

  def wait_for_new_instance
    new_instance = @replacement_instances.shift

    unless new_instance
      raise 'No more instances with call to #wait_for_new_instance!'
    end

    @instances << new_instance
    new_instance.id
  end

  def instance_health(id)
    next_health = @instance_healths.fetch(id, []).shift

    raise "No InstanceHealth responses set for #{id}!" unless next_health

    next_health
  end

  def non_conforming_instances
    @instances.select { |i| !i.conforming }.map(&:id)
  end

  def detach_instance(id, decrement:)
    @desired -= 1 if decrement
    @instances.delete_if { |i| i.id == id }
  end
end
