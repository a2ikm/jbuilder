require 'test/unit'
require 'mocha/setup'
require 'action_view'
require 'action_view/testing/resolvers'
require 'active_support/cache'
require 'jbuilder'

module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

class JbuilderTemplateTest < ActionView::TestCase
  setup do
    @context = self
    Rails.cache.clear
  end

  def partials
    { '_partial.json.jbuilder' => 'json.content "hello"' }
  end

  def render_jbuilder(source)
    @rendered = []
    lookup_context.view_paths = [ActionView::FixtureResolver.new(partials.merge('test.json.jbuilder' => source))]
    ActionView::Template.new(source, 'test', JbuilderHandler, :virtual_path => 'test').render(self, {}).strip
  end

  test 'rendering' do
    json = render_jbuilder <<-JBUILDER
      json.content 'hello'
    JBUILDER

    assert_equal 'hello', MultiJson.load(json)['content']
  end

  test 'key_format! with parameter' do
    json = render_jbuilder <<-JBUILDER
      json.key_format! :camelize => [:lower]
      json.camel_style 'for JS'
    JBUILDER

    assert_equal ['camelStyle'], MultiJson.load(json).keys
  end

  test 'key_format! propagates to child elements' do
    json = render_jbuilder <<-JBUILDER
      json.key_format! :upcase
      json.level1 'one'
      json.level2 do
        json.value 'two'
      end
    JBUILDER

    result = MultiJson.load(json)
    assert_equal 'one', result['LEVEL1']
    assert_equal 'two', result['LEVEL2']['VALUE']
  end

  test 'partial! renders partial' do
    json = render_jbuilder <<-JBUILDER
      json.partial! 'partial'
    JBUILDER

    assert_equal 'hello', MultiJson.load(json)['content']
  end

  test 'fragment caching a JSON object' do
    class << @context
      undef_method :fragment_name_with_digest if self.method_defined?(:fragment_name_with_digest)
      undef_method :cache_fragment_name if self.method_defined?(:cache_fragment_name)
    end

    render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.name 'Cache'
      end
    JBUILDER

    json = render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.name 'Miss'
      end
    JBUILDER

    parsed = MultiJson.load(json)
    assert_equal 'Cache', parsed['name']
  end

  test 'fragment caching deserializes an array' do
    class << @context
      undef_method :fragment_name_with_digest if self.method_defined?(:fragment_name_with_digest)
      undef_method :cache_fragment_name if self.method_defined?(:cache_fragment_name)
    end

    render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.array! %w(a b c)
      end
    JBUILDER

    json = render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.array! %w(1 2 3)
      end
    JBUILDER

    parsed = MultiJson.load(json)
    assert_equal %w(a b c), parsed
  end

  test 'fragment caching works with previous version of cache digests' do
    class << @context
      undef_method :cache_fragment_name if self.method_defined?(:cache_fragment_name)
    end

    @context.expects :fragment_name_with_digest

    render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.name 'Cache'
      end
    JBUILDER
  end

  test 'fragment caching works with current cache digests' do
    class << @context
      undef_method :fragment_name_with_digest if self.method_defined?(:fragment_name_with_digest)
    end

    @context.expects :cache_fragment_name

    render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.name 'Cache'
      end
    JBUILDER
  end

  test 'fragment caching falls back on ActiveSupport::Cache.expand_cache_key' do
    class << @context
      undef_method :fragment_name_with_digest if self.method_defined?(:fragment_name_with_digest)
      undef_method :cache_fragment_name if self.method_defined?(:cache_fragment_name)
    end

    ActiveSupport::Cache.expects :expand_cache_key

    render_jbuilder <<-JBUILDER
      json.cache! 'cachekey' do
        json.name 'Cache'
      end
    JBUILDER
  end

end