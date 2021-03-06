require "spec_helper"

describe "Tokenizer" do
  let(:parser) { @context["handlebars"] }
  let(:lexer) { @context["handlebars"]["lexer"] }

  Token = Struct.new(:name, :text)

  def tokenize(string)
    lexer.setInput(string)
    out = []

    while result = parser.terminals_[lexer.lex] and result != "EOF"
      out << Token.new(result, lexer.yytext)
    end

    out
  end

  RSpec::Matchers.define :match_tokens do |tokens|
    match do |result|
      result.map(&:name).should == tokens
    end
  end

  RSpec::Matchers.define :be_token do |name, string|
    match do |token|
      token.name.should == name
      token.text.should == string
    end
  end

  it "tokenizes a simple mustache as 'OPEN ID CLOSE'" do
    result = tokenize("{{foo}}")
    result.should match_tokens(%w(OPEN ID CLOSE))
    result[1].should be_token("ID", "foo")
  end

  it "tokenizes a path as 'OPEN (ID SEP)* ID CLOSE'" do
    result = tokenize("{{../foo/bar}}")
    result.should match_tokens(%w(OPEN ID SEP ID SEP ID CLOSE))
    result[1].should be_token("ID", "..")
  end

  it "tokenizes a path with this/foo as OPEN ID SEP ID CLOSE" do
    result = tokenize("{{this/foo}}")
    result.should match_tokens(%w(OPEN ID SEP ID CLOSE))
    result[1].should be_token("ID", "this")
    result[3].should be_token("ID", "foo")
  end

  it "tokenizes a simple mustahe with spaces as 'OPEN ID CLOSE'" do
    result = tokenize("{{  foo  }}")
    result.should match_tokens(%w(OPEN ID CLOSE))
    result[1].should be_token("ID", "foo")
  end

  it "tokenizes raw content as 'CONTENT'" do
    result = tokenize("foo {{ bar }} baz")
    result.should match_tokens(%w(CONTENT OPEN ID CLOSE CONTENT))
    result[0].should be_token("CONTENT", "foo ")
    result[4].should be_token("CONTENT", " baz")
  end

  it "tokenizes a partial as 'OPEN_PARTIAL ID CLOSE'" do
    result = tokenize("{{> foo}}")
    result.should match_tokens(%w(OPEN_PARTIAL ID CLOSE))
  end

  it "tokenizes a partial with context as 'OPEN_PARTIAL ID ID CLOSE'" do
    result = tokenize("{{> foo bar }}")
    result.should match_tokens(%w(OPEN_PARTIAL ID ID CLOSE))
  end

  it "tokenizes a partial without spaces as 'OPEN_PARTIAL ID CLOSE'" do
    result = tokenize("{{>foo}}")
    result.should match_tokens(%w(OPEN_PARTIAL ID CLOSE))
  end

  it "tokenizes a partial space at the end as 'OPEN_PARTIAL ID CLOSE'" do
    result = tokenize("{{>foo  }}")
    result.should match_tokens(%w(OPEN_PARTIAL ID CLOSE))
  end

  it "tokenizes a comment as 'COMMENT'" do
    result = tokenize("foo {{! this is a comment }} bar {{ baz }}")
    result.should match_tokens(%w(CONTENT COMMENT CONTENT OPEN ID CLOSE))
    result[1].should be_token("COMMENT", " this is a comment ")
  end

  it "tokenizes open and closing blocks as 'OPEN_BLOCK ID CLOSE ... OPEN_ENDBLOCK ID CLOSE'" do
    result = tokenize("{{#foo}}content{{/foo}}")
    result.should match_tokens(%w(OPEN_BLOCK ID CLOSE CONTENT OPEN_ENDBLOCK ID CLOSE))
  end

  it "tokenizes inverse sections as 'OPEN_INVERSE CLOSE'" do
    tokenize("{{^}}").should match_tokens(%w(OPEN_INVERSE CLOSE))
  end

  it "tokenizes inverse sections with ID as 'OPEN_INVERSE ID CLOSE'" do
    result = tokenize("{{^foo}}")
    result.should match_tokens(%w(OPEN_INVERSE ID CLOSE))
    result[1].should be_token("ID", "foo")
  end

  it "tokenizes inverse sections with ID and spaces as 'OPEN_INVERSE ID CLOSE'" do
    result = tokenize("{{^ foo  }}")
    result.should match_tokens(%w(OPEN_INVERSE ID CLOSE))
    result[1].should be_token("ID", "foo")
  end

  it "tokenizes mustaches with params as 'OPEN ID ID ID CLOSE'" do
    result = tokenize("{{ foo bar baz }}")
    result.should match_tokens(%w(OPEN ID ID ID CLOSE))
    result[1].should be_token("ID", "foo")
    result[2].should be_token("ID", "bar")
    result[3].should be_token("ID", "baz")
  end

  it "tokenizes mustaches with String params as 'OPEN ID ID STRING CLOSE'" do
    result = tokenize("{{ foo bar \"baz\" }}")
    result.should match_tokens(%w(OPEN ID ID STRING CLOSE))
    result[3].should be_token("STRING", "baz")
  end

  it "tokenizes String params with spaces inside as 'STRING'" do
    result = tokenize("{{ foo bar \"baz bat\" }}")
    result.should match_tokens(%w(OPEN ID ID STRING CLOSE))
    result[3].should be_token("STRING", "baz bat")
  end

  it "tokenizes String params with escapes quotes as 'STRING'" do
    result = tokenize(%|{{ foo "bar\\"baz" }}|)
    result.should match_tokens(%w(OPEN ID STRING CLOSE))
    result[2].should be_token("STRING", %{bar"baz})
  end

  it "does not time out in a mustache with a single } followed by EOF" do
    Timeout.timeout(1) { tokenize("{{foo}").should match_tokens(%w(OPEN ID)) }
  end

  it "does not time out in a mustache when invalid ID characters are used" do
    Timeout.timeout(1) { tokenize("{{foo & }}").should match_tokens(%w(OPEN ID)) }
  end
end
