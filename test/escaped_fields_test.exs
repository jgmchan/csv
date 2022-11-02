defmodule EscapedFieldsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  test "parses empty escape sequences" do
    stream = ["\"\",e"] |> to_line_stream
    result = CSV.decode!(stream) |> Enum.take(2)

    assert result == [["", "e"]]
  end

  test "parses empty escape with custom escape characters" do
    stream = ["@@,e"] |> to_line_stream
    result = CSV.decode!(stream, escape_character: ?@) |> Enum.take(2)

    assert result == [["", "e"]]
  end

  test "parses escape sequences on the last line without a newline" do
    stream = ["a,\"b\"\n", "c,\"d\""] |> to_stream
    result = CSV.decode!(stream) |> Enum.take(2)

    assert result == [["a", "b"], ["c", "d"]]
  end

  test "parses escape sequences on the last line without a newline in a byte stream" do
    stream = "a,\"b\"\nc,\"d\"" |> to_byte_stream(2)
    result = CSV.decode!(stream) |> Enum.take(2)

    assert result == [["a", "b"], ["c", "d"]]
  end

  test "parses escape sequences on the last line without a newline and applies field transforms" do
    stream = ["a,\"b\"\n", "c,\"d    \""] |> to_stream
    result = CSV.decode!(stream, field_transform: &String.trim/1) |> Enum.take(2)

    assert result == [["a", "b"], ["c", "d"]]
  end

  test "collects rows with fields spanning multiple lines" do
    stream = ["a,\"be", "c,d\ne,f\"", "g,h", "i,j", "k,l"] |> to_line_stream
    result = CSV.decode!(stream) |> Enum.take(2)

    assert result == [["a", "be\nc,d\ne,f"], ~w(g h)]
  end

  test "collects rows with fields spanning multiple lines and custom escape characters" do
    stream = ["a,@be", "c,d\ne,f@", "g,h", "i,j", "k,l"] |> to_line_stream
    result = CSV.decode!(stream, escape_character: ?@) |> Enum.take(2)

    assert result == [["a", "be\nc,d\ne,f"], ~w(g h)]
  end

  test "parses escape sequences in each field" do
    stream = ["a,\"b\",\"c\"", "\"d\",e,\"f\"\"\""] |> to_line_stream
    result = CSV.decode(stream) |> Enum.take(2)

    assert result == [ok: ["a", "b", "c"], ok: ["d", "e", "f\""]]
  end

  test "parses escape sequences containing escaped double quotes and applies transforms" do
    stream =
      ["  a  ,\"   \"\"b\"\"    \",\"    \"\"     c     \"\"      \"\"      \""] |> to_line_stream

    result = CSV.decode(stream, field_transform: &String.trim/1) |> Enum.take(1)

    assert result == [ok: ["a", "\"b\"", "\"     c     \"      \""]]
  end

  test "collects rows with fields and escape sequences spanning multiple lines" do
    stream =
      [
        # line 1
        ",,\"\r\n",
        "field three of line one\r\n",
        "contains \"\"quoted\"\" text, \r\n",
        "multiple \"\"linebreaks\"\"\r\n",
        "and ends on a new line.\"\r\n",
        # line 2
        "line two has,\"a simple, quoted second field\r\n",
        "with one newline\",and a standard third field\r\n",
        # line 3
        "\"line three begins with an escaped field,\r\n",
        " continues with\",\"an escaped field,\r\n",
        "and ends\",\"with\r\n",
        "an escaped field\"\r\n",
        # line 4
        "\"field two in\r\n",
        "line four\",\"\r\n",
        "begins and ends with a newline\r\n",
        "\",\", and field three\r\n",
        "\"\"\"\"\r\n",
        "is full of newlines and quotes\r\n\"\r\n",
        # line 5
        "\"line five has an empty line in field two\",\"\r\n",
        "\r\n",
        "\",\"\"\"and a doubly quoted third field\r\n",
        "\"\"\"\r\n",
        # line 6 only contains quotes and new lines
        "\"\"\"\"\"\",\"\"\"\r\n",
        "\"\"\"\"\r\n",
        "\",\"\"\"\"\r\n",
        # line 7
        "line seven has an intermittent,\"quote\r\n",
        "right after\r\n",
        "\"\"a new line\r\n",
        "and\r\n",
        "ends with a standard, \"\"\",unquoted third field\r\n"
      ]
      |> to_stream

    result = CSV.decode!(stream) |> Enum.to_list()

    assert result == [
             [
               "",
               "",
               "\r\nfield three of line one\r\ncontains \"quoted\" text, \r\nmultiple \"linebreaks\"\r\nand ends on a new line."
             ],
             [
               "line two has",
               "a simple, quoted second field\r\nwith one newline",
               "and a standard third field"
             ],
             [
               "line three begins with an escaped field,\r\n continues with",
               "an escaped field,\r\nand ends",
               "with\r\nan escaped field"
             ],
             [
               "field two in\r\nline four",
               "\r\nbegins and ends with a newline\r\n",
               ", and field three\r\n\"\"\r\nis full of newlines and quotes\r\n"
             ],
             [
               "line five has an empty line in field two",
               "\r\n\r\n",
               "\"and a doubly quoted third field\r\n\""
             ],
             [
               "\"\"",
               "\"\r\n\"\"\r\n",
               "\""
             ],
             [
               "line seven has an intermittent",
               "quote\r\nright after\r\n\"a new line\r\nand\r\nends with a standard, \"",
               "unquoted third field"
             ]
           ]
  end

  test "collects rows with fields and escape sequences spanning multiple lines that are byte streamed" do
    1..100
    |> Enum.each(fn size ->
      stream =
        ",,\"\r\nfield three of line one\r\ncontains \"\"quoted\"\" text, \r\nmultiple \"\"linebreaks\"\"\r\nand ends on a new line.\"\r\nline two has,\"a simple, quoted second field\r\nwith one newline\",and a standard third field\r\n\"line three begins with an escaped field,\r\n continues with\",\"an escaped field,\r\nand ends\",\"with\r\nan escaped field\"\r\n\"field two in\r\nline four\",\"\r\nbegins and ends with a newline\r\n\",\", and field three\r\n\"\"\"\"\r\nis full of newlines and quotes\r\n\"\r\n\"line five has an empty line in field two\",\"\r\n\r\n\",\"\"\"and a doubly quoted third field\r\n\"\"\"\r\n\"\"\"\"\"\",\"\"\"\r\n\"\"\"\"\r\n\",\"\"\"\"\r\nline seven has an intermittent,\"quote\r\nright after\r\n\"\"a new line\r\nand\r\nends with a standard, \"\"\",unquoted third field\r\n"
        |> to_byte_stream(size)

      result = CSV.decode!(stream) |> Enum.to_list()

      assert result == [
               [
                 "",
                 "",
                 "\r\nfield three of line one\r\ncontains \"quoted\" text, \r\nmultiple \"linebreaks\"\r\nand ends on a new line."
               ],
               [
                 "line two has",
                 "a simple, quoted second field\r\nwith one newline",
                 "and a standard third field"
               ],
               [
                 "line three begins with an escaped field,\r\n continues with",
                 "an escaped field,\r\nand ends",
                 "with\r\nan escaped field"
               ],
               [
                 "field two in\r\nline four",
                 "\r\nbegins and ends with a newline\r\n",
                 ", and field three\r\n\"\"\r\nis full of newlines and quotes\r\n"
               ],
               [
                 "line five has an empty line in field two",
                 "\r\n\r\n",
                 "\"and a doubly quoted third field\r\n\""
               ],
               [
                 "\"\"",
                 "\"\r\n\"\"\r\n",
                 "\""
               ],
               [
                 "line seven has an intermittent",
                 "quote\r\nright after\r\n\"a new line\r\nand\r\nends with a standard, \"",
                 "unquoted third field"
               ]
             ]
    end)
  end
end
