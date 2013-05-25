describe 'source cell', ->
  src = null
  beforeEach -> src = rx.cell()
  it 'initially contains null', ->
    expect(src.get()).toBe(null)
  it 'has get value that is same as last set value', ->
    src.set(1)
    expect(src.get()).toBe(1)

describe 'dependent cell', ->
  dep = src = null
  beforeEach ->
    src = rx.cell()
    dep = rx.bind -> src.get()
  it 'always reflects the dependency', ->
    expect(src.get()).toBe(dep.get())
    src.set(0)
    expect(src.get()).toBe(dep.get())
    expect(src.get()).toBe(0)
    src.set(1)
    expect(src.get()).toBe(dep.get())
    expect(src.get()).toBe(1)
  it 'cannot be set', ->
    expect(-> dep.set(0)).toThrow()
