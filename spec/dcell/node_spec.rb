describe DCell::Node do
  before do
    @node = DCell::Node[TEST_NODE[:id]]
    @node.id.should == TEST_NODE[:id]
  end

  it "finds all available nodes" do
    nodes = DCell::Node.all
    nodes.should include(DCell.me)
  end

  it "finds remote actors" do
    actor = @node[:test_actor]
    actor.value.should == 42
  end

  it "lists remote actors" do
    @node.actors.should include :test_actor
    @node.all.should include :test_actor
  end

  context :crashing, :pending => RUBY_ENGINE=="jruby" do
    before :each do
    end

    it "retries remote actor lookup" do
      @node[:test_actor].suicide
      sleep 2
      @node[:test_actor].value.should == 42
    end

    it "raises exception on a sync call to dead actor" do
      actor = @node[:test_actor]
      actor.suicide
      sleep 2
      expect {actor.value}.to raise_error Celluloid::DeadActorError
    end

    it "raises exception on access to the value of future operation if remote actor dies" do
      actor = @node[:test_actor]
      actor.async.suicide 0
      future = actor.future.value
      sleep 2
      expect {future.value}.to raise_error Celluloid::DeadActorError
    end

    it "raises exception on access to the value of future operation which crashed the actor" do
      actor = @node[:test_actor]
      future = actor.future.suicide 0
      sleep 2
      expect {future.value}.to raise_error Celluloid::DeadActorError
    end

    it "sync operation raises exception if remote actor dies during async operation" do
      actor = @node[:test_actor]
      actor.async.suicide 0
      sleep 2
      expect {actor.value}.to raise_error Celluloid::DeadActorError
    end
  end
end
