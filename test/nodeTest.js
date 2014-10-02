//must have run build first
var rx, rxt;
try{
  console.log("Node test beginning.");
  rx = require('../.tmp/reactive.js');
  var c = rx.cell(3.14);
  if(c.get()!=3.14)
    throw "rx.cell not working correctly";
  c.set(2.718);
  if(c.get()!=2.718)
    throw "rx.cell not working correctly";
  console.log("Node smoke-test completed successfully.")
}
catch(ex){
  console.log("Node test suite failing: " + ex.message);
  process.exit(1);
}
