require 'yaml'
require 'erb'

module MSEHelp
  class << self
    attr_accessor :corpus, :model
    def load
      @corpus = YAML.load_file File.dirname(__FILE__) + '/MSECorpus.yaml'
      @model = IO.read File.dirname(__FILE__) + '/MSEModel.erb'
    end
  end
  load

  def self.format_time(time)
    time.strftime "%Y-%m-%d %H:%M:%S"
  end

  def self.format_monster_type(card)
    card_types = MSEHelp.corpus['card_type']
    special_types = card_types['special']
    return special_types[card.id] if special_types.key? card.id
    for type in card_types.keys - ['special']
      return card_types[type] if card.send(('is_type_' + type).to_sym)
    end
    'effect monster'
  end

  def self.format_level(card)
    if card.is_type_monster
      format_level_monster card
    else
      format_level_spell_trap card
    end
  end

  def self.format_level_monster(card)
    MSEHelp.corpus['level']['star'] * card.level
  end

  def self.format_level_spell_trap(card)
    types = MSEHelp.corpus['spell_trap_type']
    for key in types.keys
      return types[key] if card.send(('is_type_' + key).to_sym)
    end
    types['normal']
  end

  def self.format_attribute(card)
    attributes = MSEHelp.corpus['attributes']
    for key in attributes.keys
      if card.send(('is_attribute_' + key).to_sym)
        return attributes[key]
      end
    end
    ''
  end

  def self.format_race(card, environment)
    races = environment.races
    for race in races
      if card.send(('is_race_' + race[:name]).to_sym)
        return fix_race_name race[:text], environment.locale
      end
    end
    ''
  end

  def self.fix_race_name(text, locale)
    language_name = MSEHelp.corpus['locale_hash'][locale]
    rename_fix = MSEHelp.corpus['race_name_fix'][language_name]
    return text if rename_fix == nil
    sprintf rename_fix, text
  end

  @@cross_monster_types = {}

  def self.link_cross_monster_types(environment)
    monster_types = MSEHelp.corpus['monster_type']
    hash = {}
    environment.types.each { |type| hash[type[:name]] = type }
    @@cross_monster_types[environment] = monster_types.map { |type_name| hash[type_name] }
    @@cross_monster_types[environment]
  end

  def self.format_type(card, environment)
    types = []
    types.push format_race card, environment
    monster_types = @@cross_monster_types[environment]
    monster_types = link_cross_monster_types(environment) if monster_types == nil
    for monster_type in monster_types.select { |single_monster_type| single_monster_type != nil }
      types.push monster_type[:text] if card.send(('is_type_' + monster_type[:name]).to_sym)
    end
    types
  end

  def self.separate_rule_text(text, locale)
    text = text.gsub("\r", "\n").gsub("\n\n", "\n")
    rule_text_separator = MSEHelp.corpus['rule_text_separator'][locale]
    if rule_text_separator == nil
      ygopro_images_manager_logger.warning "No rule text separator defined for #{locale}, will do no separate."
      return [reline_text(text), '']
    end
    words = text.split rule_text_separator['monster_effect_head']
    return [reline_text(text), ''] if words.count <= 1
    pendulum_effect = words[0].gsub rule_text_separator['pendulum_effect_head'], ''
    pendulum_effect = '' if pendulum_effect == nil
    [reline_text(words[words.length - 1]), reline_text(pendulum_effect)]
  end

  def self.reline_text(text)
    text.gsub! "。\n", '。'
    text.gsub! "\n", "\n\t\t"
    text = text.strip
    text
  end

  def self.format_link_markers(card)
    link_marker_positions = MSEHelp.corpus['link_marker_positions']
    link_markers = {}
    card.link_markers.each_with_index { |marker, index| link_markers[link_marker_positions[index]] = 'yes' if marker }
    link_markers
  end

  def self.format_value(value)
    value == -2 ? '?' : value.to_s
  end

  def self.format_cards(cards, environment)
    mse_config = {
        mse_version: MSEHelp.corpus['mse_version'],
        mse_stylesheet: MSEHelp.corpus['mse_stylesheet'],
        language_name: MSEHelp.corpus['locale_hash'][environment.locale]
    }
    ygopro_images_manager_logger.info "MSE is generating #{cards.count} card [set] data..."
    ERB.new(MSEHelp.model, 0, '-').result(binding).gsub '  ', "\t"
  end

  def self.set_corpus(corpus)
    IO.write File.dirname(__FILE__) + '/MSECorpus.yaml', corpus
    MSEHelp.load
  end

  def self.set_model(model)
    IO.write File.dirname(__FILE__) + '/MSEModel.erb', model
    MSEHelp.load
  end
end