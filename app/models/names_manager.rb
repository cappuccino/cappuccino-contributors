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
    case name
    when /\A\d+\z/
      # Remove side effects of [5684]
      fallback
    when /\A\s*\z/
      fallback
    when /^See rails ML/, /RAILS_ENV/
      fallback
    when /RubyConf/
      # RubyConf '05
      fallback
    when /^Includes duplicates of changes/
      # Includes duplicates of changes from 1.1.4 - 1.2.3
      fallback
    when 'update from Trac'
      fallback
    when 'Marcel Mollina Jr.'
      # typo, there are two ls
      'Marcel Molina Jr.'
    when 'Thanks to Austin Ziegler for Transaction::Simple'
      'Austin Ziegler'
    when 'Hongli Lai (Phusion'
      'Hongli Lai (Phusion)'
    when 'Leon Bredt'
      'Leon Breedt'
    when 'nik.wakelin Koz'
      ['nik.wakelin', 'Koz']
    when 'Jim Remsik and Tim Pope'
      ['Jim Remsik', 'Tim Pope']
    when 'Jeremy Hopple and Kevin Clark'
      ['Jeremy Hopple', 'Kevin Clark']
    when 'Yehuda Katz and Carl Lerche'
      ['Yehuda Katz', 'Carl Lerche']
    when 'Ross Kaffenburger and Bryan Helmkamp'
      ['Ross Kaffenberger', 'Bryan Helmkamp'] # Kaffenberger is correct
    when "#{email('me', 'jonnii.com')} #{email('rails', 'jeffcole.net')} Marcel Molina Jr."
      [email('me', 'jonnii.com'), email('rails', 'jeffcole.net'), 'Marcel Molina Jr.']
    when "#{email('jeremy', 'planetargon.com')} Marcel Molina Jr."
      [email('jeremy', 'planetargon.com'), 'Marcel Molina Jr.']
    when "#{email('matt', 'mattmargolis.net')} Marcel Molina Jr."
      [email('matt', 'mattmargolis.net'), 'Marcel Molina Jr.']
    when "#{email('doppler', 'gmail.com')} #{email('phil.ross', 'gmail.com')}"
      [email('doppler', 'gmail.com'), email('phil.ross', 'gmail.com')]
    when 'After much pestering from Dave Thomas'
      'Dave Thomas'
    when '=?utf-8?q?Adam=20Cig=C3=A1nek?='
      'Adam Cigánek'
    when 'Aredridel/earlier work by Michael Neumann'
      ['Aredridel', 'Michael Neumann']
    when /\A(Spotted|Suggested|Investigation|earlier work|Aggregated)\s+by\s+(.*)/i
      # Spotted by Kevin Bullock
      # Suggested by Carl Youngblood
      # Investigation by Scott
      # earlier work by Michael Neumann
      # Aggregated by schoenm ~ at ~ earthlink.net
      $2
    when /\Avia\s+(.*)/i
      # via Tim Bray
      $1
    when CONNECTORS_REGEXP # There are lots of these, even with a combination of connectors.
      # [Adam Milligan, Pratik]
      # [Rick Olson/Nicholas Seckar]
      # [Kevin Clark & Jeremy Hopple]
      # Yehuda Katz + Carl Lerche
      name.split(CONNECTORS_REGEXP).map(&:strip).reject do |part|
        part == 'others' || # foamdino ~ at ~ gmail.com/others
        part == '?'         # Sam Stephenson/?
      end
    else
      name
    end
  end
end
