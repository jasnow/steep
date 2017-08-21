require "test_helper"

class TypeAssignabilityTest < Minitest::Test
  T = Steep::Types
  Parser = Steep::Parser

  def parse_method(src)
    Parser.parse_method(src)
  end

  def parse_signature(src, &block)
    Parser.parse_signature(src).each(&block)
  end

  def test_any_any
    assignability = Steep::TypeAssignability.new
    assert assignability.test(src: T::Any.new, dest: T::Any.new)
  end

  def test_if1
    if1, if2 = Parser.parse_signature(<<-EOS)
interface _Foo
end

interface _Bar
end
    EOS

    assignability = Steep::TypeAssignability.new do |a|
      a.add_signature if1
      a.add_signature if2
    end

    assert assignability.test(src: T::Name.interface(name: :_Foo), dest: T::Name.interface(name: :_Bar))
  end

  def test_if2
    if1, if2 = Parser.parse_signature(<<-EOS)
interface _Foo
  def foo: -> any
end

interface _Bar
  def foo: -> any
end
    EOS

    assignability = Steep::TypeAssignability.new do |a|
      a.add_signature if1
      a.add_signature if2
    end

    assert assignability.test(src: T::Name.interface(name: :_Foo), dest: T::Name.interface(name: :_Bar))
  end

  def test_method1
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _A
  def foo: -> any
end

interface _B
  def bar: -> any
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test_method(parse_method("(_A) -> any"), parse_method("(_A) -> any"), [])
    assert assignability.test_method(parse_method("(_A) -> any"), parse_method("(any) -> any"), [])
    assert assignability.test_method(parse_method("(any) -> any"), parse_method("(_A) -> any"), [])
    refute assignability.test_method(parse_method("() -> any"), parse_method("(_A) -> any"), [])
    refute assignability.test_method(parse_method("(_A) -> any"), parse_method("(_B) -> any"), [])

    assert assignability.test_method(parse_method("(_A, ?_B) -> any"), parse_method("(_A) -> any"), [])
    refute assignability.test_method(parse_method("(_A) -> any"), parse_method("(_A, ?_B) -> any"), [])

    refute assignability.test_method(parse_method("(_A, ?_A) -> any"), parse_method("(*_A) -> any"), [])
    refute assignability.test_method(parse_method("(_A, ?_A) -> any"), parse_method("(*_B) -> any"), [])

    assert assignability.test_method(parse_method("(*_A) -> any"), parse_method("(_A) -> any"), [])
    refute assignability.test_method(parse_method("(*_A) -> any"), parse_method("(_B) -> any"), [])

    assert assignability.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _A) -> any"), [])
    refute assignability.test_method(parse_method("(name: _A, email: _B) -> any"), parse_method("(name: _A) -> any"), [])

    assert assignability.test_method(parse_method("(name: _A, ?email: _B) -> any"), parse_method("(name: _A) -> any"), [])
    refute assignability.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _A, ?email: _B) -> any"), [])

    refute assignability.test_method(parse_method("(name: _A) -> any"), parse_method("(name: _B) -> any"), [])

    assert assignability.test_method(parse_method("(**_A) -> any"), parse_method("(name: _A) -> any"), [])
    assert assignability.test_method(parse_method("(**_A) -> any"), parse_method("(name: _A, **_A) -> any"), [])
    assert assignability.test_method(parse_method("(name: _B, **_A) -> any"), parse_method("(name: _B, **_A) -> any"), [])

    refute assignability.test_method(parse_method("(name: _A) -> any"), parse_method("(**_A) -> any"), [])
    refute assignability.test_method(parse_method("(email: _B, **B) -> any"), parse_method("(**_B) -> any"), [])
    refute assignability.test_method(parse_method("(**_B) -> any"), parse_method("(**_A) -> any"), [])
    refute assignability.test_method(parse_method("(name: _B, **_A) -> any"), parse_method("(name: _A, **_A) -> any"), [])
  end

  def test_method2
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _S
end

interface _T
  def foo: -> any
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test(src: T::Name.interface(name: :_T), dest: T::Name.interface(name: :_S))

    assert assignability.test_method(parse_method("() -> _T"), parse_method("() -> _S"), [])
    refute assignability.test_method(parse_method("() -> _S"), parse_method("() -> _T"), [])

    assert assignability.test_method(parse_method("(_S) -> any"), parse_method("(_T) -> any"), [])
    refute assignability.test_method(parse_method("(_T) -> any"), parse_method("(_S) -> any"), [])
  end

  def test_recursively
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _S
  def this: -> _S
end

interface _T
  def this: -> _T
  def foo: -> any
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test(src: T::Name.interface(name: :_T), dest: T::Name.interface(name: :_S))
    refute assignability.test(src: T::Name.interface(name: :_S), dest: T::Name.interface(name: :_T))
  end

  def test_union_intro
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _X
  def x: () -> any
end

interface _Y
  def y: () -> any
end

interface _Z
  def z: () -> any
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                                         T::Name.interface(name: :_Y)]),
                              src: T::Name.interface(name: :_X))

    assert assignability.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                                         T::Name.interface(name: :_Y),
                                                         T::Name.interface(name: :_Z)]),
                              src: T::Union.new(types: [T::Name.interface(name: :_X),
                                                        T::Name.interface(name: :_Y)]))

    refute assignability.test(dest: T::Union.new(types: [T::Name.interface(name: :_X),
                                                         T::Name.interface(name: :_Y)]),
                              src: T::Name.interface(name: :_Z))
  end

  def test_union_elim
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _X
  def x: () -> any
  def z: () -> any
end

interface _Y
  def y: () -> any
  def z: () -> any
end

interface _Z
  def z: () -> any
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test(dest: T::Name.interface(name: :_Z),
                              src: T::Union.new(types: [T::Name.interface(name: :_X),
                                                        T::Name.interface(name: :_Y)]))

    refute assignability.test(dest: T::Name.interface(name: :_X),
                              src: T::Union.new(types: [T::Name.interface(name: :_Z),
                                                        T::Name.interface(name: :_Y)]))
  end

  def test_union_method
    assignability = Steep::TypeAssignability.new do |a|
      parse_signature(<<-EOS).each do |interface|
interface _X
  def f: () -> any
       | (any) -> any
       | (any, any) -> any
end

interface _Y
  def f: () -> any
       | (_X) -> _X
end
      EOS
        a.add_signature interface
      end
    end

    assert assignability.test(src: T::Name.interface(name: :_X),
                              dest: T::Name.interface(name: :_Y))

    refute assignability.test(src: T::Name.interface(name: :_Y),
                              dest: T::Name.interface(name: :_X))
  end

  def test_add_signature
    klass, mod, interface, _ = parse_signature(<<-SRC).to_a
class A
end

module B
end

interface _C
end
    SRC

    assignability = Steep::TypeAssignability.new do |a|
      a.add_signature(klass)
      a.add_signature(mod)
      a.add_signature(interface)
    end

    assert_equal klass, assignability.signatures[:A]
    assert_equal mod, assignability.signatures[:B]
    assert_equal interface, assignability.signatures[:_C]
  end

  def test_add_signature_duplicated
    klass, mod, _ = parse_signature(<<-SRC).to_a
class A
end

module A
end
    SRC

    assignability = Steep::TypeAssignability.new do |a|
      a.add_signature(klass)
    end

    assert_raises RuntimeError do
      assignability.add_signature(mod)
    end
  end

  def test_block_args
    sigs = parse_signature(<<-SRC).to_a
interface _Object
  def to_s: -> any
end

interface _String
  def to_s: -> any
  def +: (_String) -> _String
end
    SRC

    assignability = Steep::TypeAssignability.new do |a|
      sigs.each do |sig|
        a.add_signature sig
      end
    end

    assert assignability.test_method(parse_method("{ (_Object) -> any } -> any"),
                                     parse_method("{ (_String) -> any } -> any"),
                                     [])

    refute assignability.test_method(parse_method("{ (_String) -> any } -> any"),
                                     parse_method("{ (_Object) -> any } -> any"),
                                     [])

    assert assignability.test_method(parse_method("{ (_Object, _String) -> any } -> any"),
                                     parse_method("{ (_Object) -> any } -> any"),
                                     [])

    assert assignability.test_method(parse_method("{ (_Object) -> any } -> any"),
                                     parse_method("{ (_Object, _String) -> any } -> any"),
                                     [])

    assert assignability.test_method(parse_method("{ (_Object, *_Object) -> any } -> any"),
                                     parse_method("{ (_Object, _String) -> any } -> any"),
                                     [])

    refute assignability.test_method(parse_method("{ (_Object, *_String) -> any } -> any"),
                                     parse_method("{ (_Object, _Object) -> any } -> any"),
                                     [])
  end
end
