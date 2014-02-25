shared_examples_for 'mutable' do |options = {}|

    let(:opts) do
        {
            single_input:   false,
            supports_nulls: true
        }.merge( options )
    end

    let(:inputs) do
        if opts[:single_input]
            { 'input1' => 'value1' }
        else
            {
                'input1' => 'value1',
                'input2' => 'value2'
            }
        end
    end

    let(:seed) { 'my_seed' }
    let(:mutable) do
        subject.inputs = inputs
        subject
    end

    describe '#mutation?' do
        context 'when the element has not been mutated' do
            it 'returns true' do
                mutable.mutation?.should be_false
            end
        end
        context 'when the element has been mutated' do
            it 'returns false' do
                mutable.mutations( seed ).first.mutation?.should be_true
            end
        end
    end

    describe '#affected_input_value' do
        it 'returns the value of the affected_input_name input' do
            elem = mutable.mutations( seed ).first
            elem.affected_input_value.should == seed
        end

        context 'when no input has been affected_input_name' do
            it 'returns nil' do
                mutable.affected_input_value.should be_nil
            end
        end
    end

    describe '#affected_input_value=' do
        it 'sets the value of the affected_input_name input' do
            elem = mutable.mutations( seed ).first
            elem.affected_input_value = 'stuff'
            elem.affected_input_value.should == 'stuff'
            elem.inputs.values.first.should == 'stuff'
        end
    end

    describe '#mutations' do
        it 'mutates #auditable' do
            mutable.mutations( seed, skip_original: true ).each do |m|
                mutable.url.should == m.url
                mutable.action.should == m.action
                mutable.inputs.should_not == m.inputs
            end
        end

        it 'sets #affected_input_name to the name of the fuzzed input' do
            checked = false
            mutable.mutations( seed, skip_original: true ).each do |m|
                mutable.url.should == m.url
                mutable.action.should == m.action
                mutable.affected_input_name.should_not == m.affected_input_name
                m.inputs[m.affected_input_name].should include seed

                checked = true
            end

            checked.should be_true
        end

        context 'with no options' do
            it 'returns all combinations' do
                # We set the skip_original option because it only applies to forms.
                mutable.mutations( seed, skip_original: true ).size.should ==
                    (opts[:single_input] ? 4 : 8) / (opts[:supports_nulls] ? 1 : 2)
            end
        end

        describe '#immutables' do
            it 'skips parameters contained parameters' do
                mutable.inputs = {
                    'input_one' => 'value 1',
                    'input_two' => 'value 2'
                }

                mutable.immutables << 'input_one'
                mutable.mutations( seed ).
                    reject { |e| e.affected_input_name != 'input_one' }.
                    should be_empty

                mutable.immutables.clear
                mutable.mutations( seed ).
                    reject { |e| e.affected_input_name != 'input_one' }.
                    should be_any
            end
        end

        context 'with option' do
            describe :respect_method,
                     if: described_class.is_a?( Arachni::Element::Capabilities::Auditable::DOM ) do

                describe true do
                    it 'does not fuzz methods' do
                        respect_method = mutable.mutations( seed, respect_method: true )
                        respect_method.map{ |m| m.method }.uniq.should eq [mutable.method]
                    end
                end
                describe false do
                    it 'fuzzes methods' do
                        no_respect_method = mutable.mutations( seed, respect_method: false )
                        no_respect_method.map{ |m| m.method }.uniq.should eq [:get, :post]
                    end
                end
                describe 'nil' do
                    it 'does not fuzz methods' do
                        respect_method = mutable.mutations( seed )
                        respect_method.map{ |m| m.method }.uniq.should == [mutable.method]
                    end
                end
            end
            describe 'Options.audit.with_both_http_methods',
                     if: described_class.is_a?( Arachni::Element::Capabilities::Auditable::DOM ) do

                it 'serves as the default value of :respect_method' do
                    Arachni::Options.audit.with_both_http_methods = true
                    no_respect_method = mutable.mutations( seed )

                    no_respect_method.map{ |m| m.method }.uniq.should eq [:get, :post]

                    Arachni::Options.audit.with_both_http_methods = false
                    respect_method = mutable.mutations( seed )

                    respect_method.map{ |m| m.method }.uniq.should == [mutable.method]
                end
            end

            describe :skip do
                it 'skips mutation of parameters with these names' do
                    mutable.mutations( seed, skip: [ 'input_one' ] )
                end
            end
            describe :param_flip,
                     if: described_class.is_a?( Arachni::Element::Capabilities::Auditable::DOM ) do

                it 'uses the seed as a param name' do
                    m = mutable.mutations( seed,
                                            format: [Arachni::Element::Capabilities::Mutable::Format::STRAIGHT],
                                            param_flip:    true,
                                            skip_original: true ).last
                    m.inputs[seed].should be_true
                end
            end
            describe :format do
                describe 'Format::STRAIGHT' do
                    it 'injects the seed as is' do
                        m = mutable.mutations( seed,
                                                format: [Arachni::Element::Capabilities::Mutable::Format::STRAIGHT],
                                                skip_original: true ).first
                        m.inputs[m.affected_input_name].should == seed
                    end
                end
                describe 'Format::APPEND' do
                    it 'appends the seed to the current value' do
                        m = mutable.mutations( seed,
                                                format: [Arachni::Element::Capabilities::Mutable::Format::APPEND],
                                                skip_original: true ).first
                        m.inputs[m.affected_input_name].should == inputs[m.affected_input_name] + seed
                    end
                end
                describe 'Format::NULL' do
                    it 'terminates the string with a null character',
                       if: described_class != Arachni::Element::Header &&
                               described_class.is_a?( Arachni::Element::Capabilities::Auditable::DOM ) do

                        m = mutable.mutations( seed,
                                                format: [Arachni::Element::Capabilities::Mutable::Format::NULL],
                                                skip_original: true ).first
                        m.inputs[m.affected_input_name].should == seed + "\0"
                    end
                end
                describe 'Format::SEMICOLON' do
                    it 'prepends the seed with a semicolon' do
                        m = mutable.mutations( seed,
                                                format: [Arachni::Element::Capabilities::Mutable::Format::SEMICOLON],
                                                skip_original: true ).first
                        m.inputs[m.affected_input_name].should == ';' + seed
                    end
                end
                describe 'Format::APPEND | Format::NULL' do
                    it 'appends the seed and terminate the string with a null character',
                       if: described_class != Arachni::Element::Header &&
                            described_class.is_a?( Arachni::Element::Capabilities::Auditable::DOM ) do

                        format = [Arachni::Element::Capabilities::Mutable::Format::APPEND |
                                      Arachni::Element::Capabilities::Mutable::Format::NULL]
                        m = mutable.mutations( seed, format: format, skip_original: true  ).first
                        m.inputs[m.affected_input_name].should == inputs[m.affected_input_name] + seed + "\0"
                    end
                end
            end
        end
    end

    describe '#affected_input_name' do
        it 'returns the name of the mutated input' do
            m = mutable.mutations( seed,
                                    format: [Arachni::Element::Capabilities::Mutable::Format::STRAIGHT],
                                    skip_original: true ).first
            m.inputs[m.affected_input_name].should_not == inputs[m.affected_input_name]
        end

        context 'when no input has been affected_input_name' do
            it 'returns nil' do
                mutable.affected_input_name.should be_nil
            end
        end
    end

    describe '#seed' do
        it 'returns the original seed' do
            seeds  = []
            values = []

            mutable.each_mutation( seed, skip_original: true ) do |m|
                seeds  << m.seed
                values << m.affected_input_value
            end

            seeds.sort.uniq.should == %w(my_seed)
        end
    end

    describe '#to_h' do
        it 'returns a hash representation of self' do
            mutation = mutable.mutations( seed ).find { |m| m.mutation? }
            hash = mutation.to_h

            hash[:affected_input_name].should == mutation.affected_input_name
            hash[:affected_input_value].should == mutation.affected_input_value
            hash[:seed].should == mutation.seed
        end

        context 'when the element is not a mutation' do
            it 'does not include mutation related data' do
                hash = mutable.to_h
                hash.should_not include :affected_input_name
                hash.should_not include :affected_input_value
                hash.should_not include :seed
            end
        end
    end

end
