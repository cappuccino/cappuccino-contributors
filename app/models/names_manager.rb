require 'set'

module NamesManager

  # Returns a set with all (canonical) contributor names known by the application.
  def self.all_names
    Set.new(Contributor.connection.select_values("SELECT NAME FROM CONTRIBUTORS"))
  end

  # Determines whether names mapping or special cases handling have been updated
  # since +ts+.
  def self.mapping_updated_since?(ts)
    File.mtime(__FILE__) > ts
  end

  # Simple trick to be able to publish this file with readable addresses.
  def self.email(user, domain)
    user + '@' + domain
  end

  # Some people appear in Rails logs under different names, there are nicks,
  # typos, email addresses, shortenings, etc. This is a hand-made list to map
  # them in order to be able to aggregate commits from the same real author.
  #
  # This mapping does not use regexps on purpose, it is more robust to put the
  # exact string equivalences. The manager has to be very strict about this.
  SEEN_ALSO_AS = {
    # canonical name           => handlers, emails, typos, etc.
    'Tom Robinson'             => ['Thomas Robinson', 'tlrobinson'],
    'Francisco Ryan Tolmasky I'=> ['Francisco Ryan Tolmasky', 'Francisco Tolmasky', 'tolmasky'],
    'Nicholas Small'           => 'nciagra'
    # canonical name           => handlers, emails, etc.
  }

  # Reverse SEEN_IN_LOG_ALSO_AS to be able to go from handler to canonical name.
  CANONICAL_NAME_FOR = {}
  SEEN_ALSO_AS.each do |name, also_as|
    [*also_as].each { |alt| CANONICAL_NAME_FOR[alt] = name }
  end

  # Returns the canonical name for +name+.
  #
  # Email addresses are removed, leading/trailing whitespace is ignored. If no
  # equivalence is known the canonical name is the resulting sanitized string
  # by definition.
  def self.canonical_name_for(name)
    name = name.sub(/<[^>]+>/, '') # remove any email address in angles
    name.strip!
    CANONICAL_NAME_FOR[name] || name
  end

  def self.special_cases
    code = File.read(__FILE__)
    code =~ /(^  #[^\n]+\n)+  def self\.handle_special_cases.*?^  end/m
    $&
  end

  CONNECTORS_REGEXP = %r{[,/&+]}

  # In some cases author names are extracted from svn messages. We look there
  # for stuff between brackets, but that's not always an author name. There
  # are lots of exceptions this method knows about.
  #
  # Note that this method is responsible for extracting names as they appear
  # in the original string, and correct typos if needed. Canonicalization is
  # done elsewhere.
  def self.handle_special_cases(name, fallback)
    name
  end
end
