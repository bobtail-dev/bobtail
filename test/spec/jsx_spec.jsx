import * as rx from '../../src/main.js';
let {snap, bind, Ev, rxt} = rx;
let {tags} = rxt;
let {div} = tags;

jasmine.CATCH_EXCEPTIONS = false;

describe('jsx', () => {
  let className;
  let salutation;

  beforeEach(() => {
    className = rx.cell('red');
    salutation = rx.cell('hello');
  });

  it('should work with tags', () => {
    const $e = <div className={className}>{salutation} world</div>;
    expect($e.text()).toBe('hello world');
    expect($e.attr('class')).toBe('red');
    salutation.set('greetings');
    expect($e.text()).toBe('greetings world');
    className.set('blue');
    expect($e.attr('class')).toBe('blue');
  });

  it('should work with functions', () => {
    const Maker = (attrs, ...contents) => <div {...attrs}>{contents}</div>;
    const $e = <Maker className={className}>{salutation} <span>world</span></Maker>;
    expect($e.text()).toBe('hello world');
  });

  it('should work with objects', () => {
    class Maker {
      constructor(attrs, ...contents) {
        this.attrs = attrs;
        this.contents = contents;
      }
      render () {
        return <div {...this.attrs}>{this.contents}</div>;
      }
    }
    const $e = <Maker className={className}>{salutation} <span>world</span></Maker>;
    expect($e.attr('class')).toBe('red');
    expect($e.text()).toBe('hello world');
    salutation.set('greetings');
    expect($e.text()).toBe('greetings world');
    className.set('blue');
    expect($e.attr('class')).toBe('blue');
  });

  it('should work with nesting', () => {
    const $e = (
      <div className={className}>
        {[() => salutation.get(), ' ', className]}, world
      </div>
    );
    expect($e.attr('class')).toBe('red');
    expect($e.text()).toBe('hello red, world');
    className.set('blue');
    expect($e.attr('class')).toBe('blue');
    expect($e.text()).toBe('hello blue, world');
  });
});