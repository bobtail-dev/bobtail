This is a great library, but at present only usable in browser due to:
  - dependency on jQuery (would have to be faked out with jsDom or other lib)
  - mixes html/jquery functionality in single file with basic rx.cell, etc...

Goals of modularizing:
  - Get basic rx functionality to be usable/testable in node
  - Use UMD or AMD format to allow loaders to import easily into any app
  - Express dependencies so that it's optional whether:
    - jquery or zepto is depended upon
    - jquery plugin is added
    - rx tags are defined
