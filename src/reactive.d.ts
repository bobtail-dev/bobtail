export type Primitive = boolean|string|number|null|undefined;

export type objTypes = 'cell'|'array'|'map';
export type typedObj<T> = {
  [s:string]: T;
}

export interface Event {
  sub(listener:(arg:any) => void): number;
  pub(data:any);
  unsub(subId:number);
}

export interface ObsCell<T> {
  get(): T;
  onSet: Event;
}

export interface SrcCell<T> extends ObsCell<T> {
  set(val:T): T;
}

export interface DepCell<T> extends ObsCell<T> {
  disconnect();
}

export interface ObsArray<T> {
  at(i:number): any;
  all(): T[];
  raw(): T[];
  length(): number;
  map(fn:(val:T) => T): DepArray<T>
  onChange: Event;
  // todo: indexed()?
}

interface NestableCell<T> extends ObsCell<T | NestableCell<T>> {}

interface FlattenableRX<T> extends ObsArray<
  T |
  NestableCell<T | FlattenableJS<T> | FlattenableRX<T>> |
  FlattenableJS<T> |
  FlattenableRX<T>
> {}

interface FlattenableJS<T> extends Array<
  T |
  NestableCell<T | FlattenableJS<T> | FlattenableRX<T>> |
  FlattenableJS<T> |
  FlattenableRX<T>
> {}

export type Flattenable<T> = FlattenableRX<T> | FlattenableJS<T>

export interface DepArray<T> extends ObsArray<T> {}

export interface diffFn<T> {
  (key:(x:T) => string): (old:Array<T>, new_:Array<T>) => Array<T>
}

export interface SrcArray<T> extends ObsArray<T> {
  constructor(init:T[], diff?: diffFn<T>);
  splice(index:number, count:number, ...additions:T[]);
  insert(x:T, i:number);
  remove(x:T);
  removeAt(i:number);
  push(x:T);
  put(i: number, x:T);
  replace(xs:T[]);
  update(xs:T[], diff?:diffFn<T>);
}

export interface ObsMap<T> {
  get(k:string|number);
  all(): typedObj<T>;
  onAdd: Event;
  onRemove: Event;
  onChange: Event;
}

export interface SrcMap<T> extends ObsMap<T> {
  put(k:string|number, v:T): T;
  remove(k:string|number);
  update(map:typedObj<T>);
}

export type TagContents =
  ObsCell<Primitive|RxTag> |
  ObsArray<Primitive|RxTag> |
  Array<Primitive|RxTag> |
  Primitive |
  RxTag;

export interface RxTag{
  rx(property:'checked'|'focused'): ObsCell<boolean>;
  rx(property:'val'): ObsCell<Primitive>;
}

export interface TagFn<T> {
  (contents?:TagContents): T & RxTag;
  (attrs: typedObj<any>, contents?:TagContents): RxTag & T;
}

export interface RawHtml {html: string;}

export interface DepMap<T> extends ObsMap<T> {}

export interface ReactiveInterface {
  cell<T>(init:T): SrcCell<T>;
  array<T>(init:Array<T>, diff?:diffFn<T>): SrcArray<T>;
  bind<T>(f: () => T): DepCell<T>;
  snap<T>(f:() => T): T;
  asyncBind<T>(init:T, f:() => T): DepCell<T>;
  lagBind<T>(lag:number, init:T, f:() => T): DepCell<T>;
  postLagBind<T>(init:T, fn:() => {val:T, ms:number}): ObsCell<T>;
  // reactify
  // autoReactify
  flatten<T>(xs:Flattenable<T>): DepArray<T>;
  onDispose(fn:() => void);
  skipFirst(fn:() => void);
  autoSub(ev:Event, listener:(arg:any) => void);
  concat<T>(...arrays:ObsArray<T>[]): DepArray<T>;
  cellToArray<T>(cell:ObsCell<T>): DepArray<T>;
  cellToMap<T>(cell:ObsCell<T>): DepMap<T>;
  basicDiff:diffFn<any>;
  smartUidify(x:any):string;
  lift(x:typedObj<any>, spec: {s: objTypes})
  liftSpec(x:typedObj<any>): {s: objTypes}
  transaction(f:() => void);
  rxt: ReactiveTemplate;
}

interface ReactiveTemplate {
  mktag(tag:string): TagFn<HTMLElement>;
  rawHtml(html:string): RawHtml;
  cast(data:typedObj<any>, types:typedObj<objTypes>);
  cast<T>(data:T, type:'cell'):ObsCell<T>;
  cast<T>(data:T[], type:'array'):ObsArray<T>;
  cast<T>(data:typedObj<T>, type:'map'):ObsMap<T>;
  smushClasses(classes: Array<string|number|null|undefined>): string;
  specialAttrs: {
    [s:string]: (
      element:RxTag,
      value: any,
      attrs: typedObj<any>,
      contents: TagContents
    ) => any;
  }
  tags: {
    'a': TagFn<HTMLAnchorElement>;
    'abbr': TagFn<HTMLElement>;
    'address': TagFn<HTMLElement>;
    'area': TagFn<HTMLAreaElement>;
    'article': TagFn<HTMLElement>;
    'aside': TagFn<HTMLElement>;
    'audio': TagFn<HTMLAudioElement>;
    'b': TagFn<HTMLElement>;
    'base': TagFn<HTMLBaseElement>;
    'bdi': TagFn<HTMLElement>;
    'bdo': TagFn<HTMLElement>;
    'blockquote': TagFn<HTMLQuoteElement>;
    'body': TagFn<HTMLBodyElement>;
    'br': TagFn<HTMLBRElement>;
    'button': TagFn<HTMLButtonElement>;
    'canvas': TagFn<HTMLCanvasElement>;
    'caption': TagFn<HTMLTableCaptionElement>;
    'cite': TagFn<HTMLElement>;
    'code': TagFn<HTMLElement>;
    'col': TagFn<HTMLTableColElement>;
    'colgroup': TagFn<HTMLTableColElement>;
    'datalist': TagFn<HTMLDataListElement>;
    'dd': TagFn<HTMLElement>; // HTMLDDElement
    'del': TagFn<HTMLModElement>;
    'details': TagFn<HTMLElement>;
    'dfn': TagFn<HTMLElement>;
    'div': TagFn<HTMLDivElement>;
    'dl': TagFn<HTMLDListElement>;
    'dt': TagFn<HTMLElement>; // HTMLDTElement
    'em': TagFn<HTMLElement>;
    'embed': TagFn<HTMLEmbedElement>;
    'fieldset': TagFn<HTMLFieldSetElement>;
    'figcaption': TagFn<HTMLElement>;
    'figure': TagFn<HTMLElement>;
    'footer': TagFn<HTMLElement>;
    'form': TagFn<HTMLFormElement>;
    'h1': TagFn<HTMLHeadingElement>;
    'h2': TagFn<HTMLHeadingElement>;
    'h3': TagFn<HTMLHeadingElement>;
    'h4': TagFn<HTMLHeadingElement>;
    'h5': TagFn<HTMLHeadingElement>;
    'h6': TagFn<HTMLHeadingElement>;
    'head': TagFn<HTMLHeadElement>;
    'header': TagFn<HTMLElement>;
    'hr': TagFn<HTMLHRElement>;
    'html': TagFn<HTMLHtmlElement>;
    'i': TagFn<HTMLElement>;
    'iframe': TagFn<HTMLIFrameElement>;
    'img': TagFn<HTMLImageElement>;
    'input': TagFn<HTMLInputElement>;
    'ins': TagFn<HTMLModElement>;
    'kbd': TagFn<HTMLElement>;
    'label': TagFn<HTMLLabelElement>;
    'legend': TagFn<HTMLLegendElement>;
    'li': TagFn<HTMLLIElement>;
    'link': TagFn<HTMLLinkElement>;
    'main': TagFn<HTMLElement>;
    'map': TagFn<HTMLMapElement>;
    'mark': TagFn<HTMLElement>;
    'menu': TagFn<HTMLMenuElement>;
    'menuitem': TagFn<HTMLElement>;
    'meta': TagFn<HTMLMetaElement>;
    'meter': TagFn<HTMLElement>;
    'nav': TagFn<HTMLElement>;
    'noscript': TagFn<HTMLElement>;
    'object': TagFn<HTMLObjectElement>;
    'ol': TagFn<HTMLOListElement>;
    'optgroup': TagFn<HTMLOptGroupElement>;
    'option': TagFn<HTMLOptionElement>;
    'p': TagFn<HTMLParagraphElement>;
    'param': TagFn<HTMLParamElement>;
    'pre': TagFn<HTMLPreElement>;
    'progress': TagFn<HTMLProgressElement>;
    'q': TagFn<HTMLQuoteElement>;
    'rp': TagFn<HTMLElement>;
    'rt': TagFn<HTMLElement>;
    'ruby': TagFn<HTMLElement>;
    's': TagFn<HTMLElement>;
    'samp': TagFn<HTMLElement>;
    'script': TagFn<HTMLScriptElement>;
    'section': TagFn<HTMLElement>;
    'select': TagFn<HTMLSelectElement>;
    'small': TagFn<HTMLElement>;
    'source': TagFn<HTMLSourceElement>;
    'span': TagFn<HTMLSpanElement>;
    'strong': TagFn<HTMLElement>;
    'style': TagFn<HTMLStyleElement>;
    'sub': TagFn<HTMLElement>;
    'summary': TagFn<HTMLElement>;
    'sup': TagFn<HTMLElement>;
    'table': TagFn<HTMLTableElement>;
    'tbody': TagFn<HTMLTableSectionElement>;
    'td': TagFn<HTMLTableCellElement>;
    'textarea': TagFn<HTMLTextAreaElement>;
    'tfoot': TagFn<HTMLTableSectionElement>;
    'th': TagFn<HTMLTableHeaderCellElement>;
    'thead': TagFn<HTMLTableSectionElement>;
    'title': TagFn<HTMLTitleElement>;
    'tr': TagFn<HTMLTableRowElement>;
    'track': TagFn<HTMLTrackElement>;
    'u': TagFn<HTMLElement>;
    'ul': TagFn<HTMLUListElement>;
    'var': TagFn<HTMLElement>;
    'video': TagFn<HTMLVideoElement>;
    'wbr': TagFn<HTMLElement>;

    // suspect

    'svg': TagFn<HTMLElement>;
    'output': TagFn<HTMLElement>;
    'keygen': TagFn<HTMLElement>;
    'math': TagFn<HTMLElement>;
		'data': TagFn<HTMLElement>;
		'time': TagFn<HTMLElement>;
  }
}
