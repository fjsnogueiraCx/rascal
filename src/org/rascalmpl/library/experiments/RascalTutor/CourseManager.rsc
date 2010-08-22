module experiments::RascalTutor::CourseManager

// The CourseManager handles all requests from the web server:
// - showConcept: displays the HTML page for a concept
// - validateAnswer: validates the answer to a specific question

import List;
import String;
import Integer;
import Graph;
import Set;
import Map;
import experiments::RascalTutor::CourseModel;
import experiments::RascalTutor::HTMLUtils;
import experiments::RascalTutor::ValueGenerator;
import experiments::RascalTutor::CourseCompiler;
import ValueIO;
import IO;
import Scripting;

loc courseRoot = |file:///Users/paulklint/software/source/roll/rascal/src/org/rascalmpl/library/experiments/RascalTutor/Courses/|;

public Course thisCourse = course("",|file://X/|,"",(),{},[],());

public ConceptName root = "";

public loc directory = |file:///Users/paulklint/software/source/roll/rascal/src/org/rascalmpl/library/experiments/RascalTutor/Courses/|;

public map[ConceptName, Concept] concepts = ();

public list[str] conceptNames = [];

public Graph[ConceptName] refinements = {};

public list[str] baseConcepts = [];

public map[str, ConceptName] related = ();

// Initialize CourseManager. 
// ** Be aware that this function should be called at the beginning of each function that can be
// ** called from a servlet to ensure proper initialisation.

private void initialize(){
  if(root == ""){
     //c = readTextValueFile(#Course, |file:///Users/paulklint/software/source/roll/rascal/src/org/rascalmpl/library/experiments/RascalTutor/Courses/Rascal/Rascal.course|);
     c = compileCourse("Rascal", "Rascal Tutorial", courseRoot);
     //c = compileCourse("Test", "Testing", courseRoot);

     reinitialize(c);
  }
}

private void reinitialize(Course c){
     thisCourse = c;
     root = c.root;
     directory = c.directory;
     concepts = c.concepts;
     conceptNames = sort(toList(domain(concepts)));
     refinements = c.refinements;
     baseConcepts = c.baseConcepts;
     related = c.related;
}

public set[QuestionName] goodAnswer = {};
public set[QuestionName] badAnswer = {};

//TODO: the webserver should be configured to serve prelude.css as a page
// with mime-type text/css. Right now it is erved as "text" and is not recognized
// by the browser.
//
// In the mean time we just paste prelude.css in the generated html-page.

public str prelude(){
  css = readFile(|file:///Users/paulklint/software/source/roll/rascal/src/org/rascalmpl/library/experiments/RascalTutor/prelude.css|);
  nbc = size(baseConcepts) - 1;
  println("prelude: <baseConcepts>");
 
  return "\n\<script type=\"text/javascript\" src=\"jquery-1.4.2.min.js\"\>\</script\>\n" +
         "\n\<script type=\"text/javascript\" src=\"prelude.js\"\>\</script\>\n" +
  
        // "\<link type=\"text/css\" rel=\"stylesheet\" href=\"prelude.css\"/\>\n";
         "\<style type=\"text/css\"\><css>\</style\>" +
          "\n\<script type=\"text/javascript\"\>var baseConcepts = new Array(<for(int i <- [0 .. nbc]){><(i==0)?"":",">\"<baseConcepts[i]>\"<}>);
          \</script\>\n";
}

// Present a concept
// *** called from servlet Show in RascalTutor

public str showConcept(ConceptName id){
 
  initialize();
  C = concepts[id];
  refs = sort(toList(refinements[id]));
  questions = C.questions;
  return html(
  	head(title(C.name) + prelude()),
  	body(
  	  section("Name", showConceptPath(id)) +
  	  searchBox() + 
  	  ((isEmpty(refs)) ? "" : "<sectionHead("Details")> <for(ref <- refs){><showConceptURL(ref, basename(ref))> &#032 <}>") +
  	  ((isEmpty(C.related)) ? "" : p("<b("Related")>: <for(rl <- C.related){><showConceptURL(related[rl], basename(rl))> &#032 <}>")) +
  	  section("Synopsis", C.synopsis) +
  	  section("Description", C.description) +
  	  section("Examples", C.examples) +
  	  section("Benefits", C.benefits) +
  	  section("Pittfalls", C.pittfalls) +
  	  ((isEmpty(questions)) ? "" : "<sectionHead("Questions")> <br()><for(quest <- questions){><showQuestion(id,quest)> <}>") +
  	  editMenu(id)
  	)
  );
}

public str section(str name, str txt){
println("section: <name>: \<\<\<<txt>\>\>\>");
  return (/^\s*$/s := txt) ? "" : div(name, sectionHead(name) +  " " + txt);
 // return div(name, b(name) + ": " + txt);
}

public str showConceptURL(ConceptName c, str name){
   return "\<a href=\"show?concept=<c>\"\><name>\</a\>";
}

public str showConceptURL(ConceptName c){
   return showConceptURL(c, c);
}

public str showConceptPath(ConceptName cn){
  names = basenames(cn);
  return "<for(int i <- [0 .. size(names)-1]){><(i==0)?"":"/"><showConceptURL(compose(names, 0, i), names[i])><}>";
}

public str searchBox(){
  return "\n\<div id=\"searchBox\"\>
              \<form method=\"GET\" id=\"searchForm\" action=\"/search\"\>\<b\>Search\</b\>\<br /\>
              \<input type=\"text\" id=\"searchField\" name=\"term\" autocomplete=\"off\"\>\<br /\>
              \<div id=\"popups\"\>\</div\>
              \</form\>
            \</div\>\n";
}

public str editMenu(ConceptName cn){
  return "\n\<div id=\"editMenu\"\>
              [\<a id=\"editAction\" href=\"/edit?concept=<cn>&new=false\"\>\<b\>Edit\</b\>\</a\>] | 
              [\<a id=\"newAction\" href=\"/edit?concept=<cn>&new=true\"\>\<b\>New\</b\>\</a\>]
            \</div\>\n";
}

// Edit a concept
// *** called from  Edit in RascalTutor

public str edit(ConceptName cn, bool newConcept){
  initialize();
  str content = "";
  if(newConcept){
    content = mkConceptTemplate(cn + "/");
  } else {
  	c = concepts[cn];
  	content = readFile(c.file);  //TODO: IO exception (not writable, does not exist)
  }
  return html(head(title("Editing <cn>") + prelude()),
              body(
              "\n\<div id=\"editArea\"\>
                    \<form method=\"POST\" action=\"/save\"\>
                    \<textarea rows=\"20\" cols=\"60\" name=\"newcontent\" class=\"editTextarea\"\><content>\</textarea\>
                    \<input type=\"hidden\" name=\"concept\" value=\"<cn>\"\> \<br /\>
                    \<input type=\"hidden\" name=\"new\" value=\"<newConcept>\"\> \<br /\>
                    \<input type=\"submit\" value=\"Save\" class=\"editSubmit\"\>
                    \</form\>
                  \</div\>\n"
             ));
}

public list[str] getPathNames(str path){
  return [ name | /<name:[A-Za-z]+>(\/|$)/ := path ];
}

// Save a concept
// *** called from servlet Edit in RascalTutor

public str save(ConceptName cn, str text, bool newConcept){
  initialize();
  if(newConcept) {
     lines = splitLines(text);
     fullName = trim(combine(getSection("Name", lines)));
     path = getPathNames(fullName);
     
     if(size(path) == 0)
     	return saveError("Name \"<fullName>\" is not a proper concept name");
     	
     cname = last(path);
     parent = head(path, size(path)-1);
     parentName = "<for(int i <- index(parent)){><(i>0)?"/":""><parent[i]><}>";
     
     // Does the concept name start with the root concept?
     
     println("name = <fullName>; path = <path>; parent = <parent>; cname = <cname>");
     if(path[0] != root)
        return saveError("Concept name should start with root concept \"<root>\"");
     
     // Does the parent directory exist?
     file = directory[file = directory.file + "/" + parentName];
     if(!exists(file))
     	return saveError("Parent directory <file> does not exist (spelling error?)");
     
     // Does the file for this concept already exist as main concept?
     file = directory[file = directory.file + "/" + fullName + suffix];
     if(exists(file))
     	return saveError("File <file> exists already");
     	
     // Does the file for this concept already exist as a subconcept?
     file = directory[file = directory.file + "/" + fullName + "/" + cname + suffix];
     if(exists(file))
     	return saveError("File <file> exists already");
     
     // Create proper directory if it does not yet exist
     dir = directory[file = directory.file + "/" + fullName];	
     if(!isDirectory(dir)){
       println("Create dir <dir>");
       if(!mkDirectory(dir))
       	  return saveError("Cannot create directory <dir>");
     }
     
     // We have now the proper file name for the new concept and process it
     file = directory[file = directory.file + "/" + fullName + "/" + cname + suffix];
     lines[0] = "Name:" + cname;  // Replace full path name by t concept name
     println("lines = <lines>");
     println("Write to file <file>");
     writeFile(file, combine(lines));
     concepts[fullName] = parseConcept(file, lines, directory.path);
     thisCourse.concepts = concepts;
     reinitialize(recompileCourse(thisCourse));
     return showConcept(fullName);
  } else {
    c = concepts[cn];
    writeFile(c.file, text);
    concepts[cn] = parseConcept(c.file, directory.path);
    return showConcept(cn);
  }
}

public str saveError(str msg){
  throw msg;
}

// TODO: This should be in the library

public bool contains(str subject, str key){
   if(size(subject) == 0)
     return false;
   for(int i <- [ 0 .. size(subject) -1])
      if(startsWith(substring(subject, i), key))
      	return true;
   return false;
}

public list[str] doSearch(str term){
  if(size(term) == 0)
    return [];
  if(/^[A-Za-z]*$/ := term)
  	return [showConceptPath(name) | name <- conceptNames, /<term>/ := name];
  if(term == "(" || term == ")" || term == ","){
     // Skip synopsis that contains function declaration
     return [showConceptPath(name) | name <- conceptNames, 
                                     /[A-Za-z0-9]+\(.*\)/ !:= concepts[name].rawSynopsis,
                                     contains(concepts[name].rawSynopsis, term) ];
  }
  return [showConceptPath(name) | name <- conceptNames, contains(concepts[name].rawSynopsis, term) ];
}

public str search(str term){
  results = doSearch(term);
  return html(body(title("Search results for <term>") + prelude()),
             (size(results) == 0) ? ("I found no results found for <i(term)>" + searchBox())
                              : ("I found the following results for <i(term)>:" + searchBox() +
                                 ul("<for(res <- results){>\<li\><res>\</li\>\n<}>"))
         );
}

// Present a Question

private str answerFormBegin(ConceptName cpid, QuestionName qid, str formClass){
	return "
\<form method=\"GET\" action=\"validate\" class=\"<formClass>\"\>
\<input type=\"hidden\" name=\"concept\" value=\"<cpid>\"\>
\<input type=\"hidden\" name=\"exercise\" value=\"<qid>\"\>\n";
}

private str answerFormEnd(str submitText, str submitClass){
  return "
\<input type=\"submit\" value=\"<submitText>\" class=\"<submitClass>\"\>
\</form\>";
}

private str anotherQuestionForm(ConceptName cpid, QuestionName qid){
	return answerFormBegin(cpid, qid, "anotherForm") + 
	"\<input type=\"hidden\" name=\"another\" value=\"yes\"\>\n" +
	answerFormEnd("I want another question", "anotherSubmit");
}

private str cheatForm(ConceptName cpid, QuestionName qid, str expr){
	return answerFormBegin(cpid, qid, "cheatForm") + 
	       "\<input type=\"hidden\" name=\"expr\" value=\"<expr>\"\>\n" +
           "\<input type=\"hidden\" name=\"cheat\" value=\"yes\"\>\n" +
           answerFormEnd("I am cheating today", "cheatSubmit");
}

public str div(str id, str txt){
	return "\n\<div id=\"<id>\"\>\n<txt>\n\</div\>\n";
}

public str status(str id, str txt){
	return "\n\<span id=\"<id>\" class=\"answerStatus\"\>\n<txt>\n\</span\>\n";
}

public str good(){
  return "\<img height=\"25\" width=\"25\" src=\"images/good.png\"/\>";
}

public str bad(){
   return "\<img height=\"25\" width=\"25\" src=\"images/bad.png\"/\>";
}

public str status(QuestionName qid){
  return (qid in goodAnswer) ? good() : ((qid in badAnswer) ? bad() : "");
}

public str showQuestion(ConceptName cpid, Question q){
println("showQuestion: <cpid>, <q>");
  qid = q.details.name;
  qdescr = "";
  qexpr  = "";
  qform = "";
  
  switch(q){
    case choiceQuestion(qid, descr, choices): {
      idx = [0 .. size(choices)-1];
      qdescr = descr;
      qform = "<for(int i <- idx){><(i>0)?br():"">\<input type=\"radio\" name=\"answer\" value=\"<i>\"\><choices[i].description>\n<}>";
    }
    case textQuestion(qid,descr,replies): {
      qdescr = descr;
      qform = "\<textarea rows=\"1\" cols=\"60\" name=\"answer\" class=\"answerText\"\>\</textarea\>";
    }
    case tvQuestion(qkind, qdetails): {
      qid    = qdetails.name;
      descr  = qdetails.descr;
      setup  = qdetails.setup;
      lstBefore = qdetails.lstBefore;
      lstAfter = qdetails.lstAfter;
      cndBefore = qdetails.cndBefore;
      cndAfter = qdetails.cndAfter;
      holeInLst = qdetails.holeInLst;
      holeInCnd = qdetails.holeInCnd;
      vars   = qdetails.vars;
      auxVars = qdetails.auxVars;
      rtype = qdetails.rtype;
	  hint = qdetails.hint;

      VarEnv env = ();
      generatedVars = [];
      for(<name, tp> <- vars){
        tp1 = generateType(tp, env);
        env[name] = <tp1, generateValue(tp1, env)>;
        generatedVars += name;
	  }

	  for(<name, exp> <- auxVars){
         exp1 = subst(exp, env);
         println("exp1 = <exp1>");
         try {
           env[name] = <parseType("<evalType(setup + exp1)>"), "<eval(setup + exp1)>">;
         } catch: throw "Error in computing <name>, <exp>";
      }
      println("env = <env>");
      
      lstBefore = escapeForHtml(subst(lstBefore, env));
      lstAfter = escapeForHtml(subst(lstAfter, env));
      cndBefore = escapeForHtml(subst(cndBefore, env));
      cndAfter = escapeForHtml(subst(cndAfter, env));
      
      qdescr = descr;
      qform = "<for(param <- generatedVars){>\<input type=\"hidden\" name=\"<param>\" value=\"<escapeForHtml(env[param].rval)>\"\>\n<}>";
      
      qtextarea = "\<textarea rows=\"1\" cols=\"30\" name=\"answer\" class=\"answerText\"\>\</textarea\>";
      
      if(lstBefore != "" || lstAfter != ""){  // A listing is present in the question
         if(holeInLst)
            qform +=  "Fill in " + "\<pre class=\"question\"\>" + lstBefore + qtextarea + lstAfter + "\</pre\>";
         else
            qform += "Given " + "\<pre class=\"question\"\>" + lstBefore + "\</pre\>";
      }
      	        
      if(qkind == valueOfExpr()){ // A Value question
      	    //if(lstBefore != "")
      	    //    if (holeInLst) qform += "and make the following true:";
      	        
         if(holeInCnd)
      	    qform += "\<pre class=\"question\"\>" + cndBefore + qtextarea + cndAfter +  "\</pre\>";
         else if(cndBefore + cndAfter != "")
            if(holeInLst)
               qform += " and make the following true:" + "\<pre class=\"question\"\>" + cndBefore + "\</pre\>";
            else
      	       qform += ((lstBefore != "") ? "Make the following true:" : "") + "\<pre class=\"question\"\>" + cndBefore + " == " + qtextarea + "\</pre\>"; 
      } else {                     // A Type question
      	if(holeInCnd)
      	   qform +=  "The type of " + tt(cndBefore) + qtextarea + tt(cndAfter) + " is " + tt(toString(generateType(rtype, env)));
         else if(holeInLst)
           qform += "and make the type of " + tt(cndBefore) + " equal to " + tt(toString(generateType(rtype, env)));  
         else
           qform += "The type of " + tt(cndBefore) + " is " + qtextarea; 
       }
    }
    default:
      throw "Unimplemented question type: <q>";
  }
  answerForm = answerFormBegin(cpid, qid, "answerForm") + qform  + br() + answerFormEnd("Give answer", "answerSubmit");

  return div(qid, b(basename(qid)) + " " + status(qid + "good", good()) + status(qid + "bad", bad()) + br() +
                  qdescr + "\n\<span id=\"answerFeedback<qid>\" class=\"answerFeedback\"\>\</span\>\n" +
                  answerForm + 
                  anotherQuestionForm(cpid, qid) + 
                  cheatForm(cpid, qid, qexpr) +  br() +
                  hr());
}

public void tstq(){
println(showQuestion("xxx", tvQuestion(typeOfExpr(), details("qid", "descr", [], "\<A:int\> + \<B:int\>", "", (), ()))));
}

public QuestionName lastQuestion = "";

// trim layout from a string
public str trim (str txt){
    return txt;
	return
	  visit(txt){
	    case /[\ \t\n\r]/ => ""
	  };
}

public Question getQuestion(ConceptName cid, QuestionName qid){
  c = concepts[cid];
  for(q <- c.questions)
  	if(q.details.name == qid)
  		return q;
  throw "Question <qid> not found";
}

// Validate an answer, also handles the requests: "cheat" and "another"
// *** called from servlet Edit in RascalTutor

public str validateAnswer(map[str,str] params){
    ConceptName cpid = params["concept"];
    QuestionName qid = params["exercise"];
    
    answer = trim(params["answer"]) ? "";
    expr = params["exp"] ? "";
    cheat = params["cheat"] ? "no";
	another = params["another"] ? "no";
	
    initialize();
	lastQuestion = qid;
	q = getQuestion(cpid, qid);
	
	println("Validate: <params>");
	println("Validate: <q>");
	if(cheat == "yes")
	   return showCheat(cpid, qid, q, expr);
	if(another == "yes")
	   return showAnother(cpid, qid, q);
	   
	switch(q){
      case choiceQuestion(qid,descr,choices): {
        try {
           int c = toInt(answer);
           return (good(_) := choices[c]) ? correctAnswer(cpid, qid) : wrongAnswer(cpid, qid, "");
        } catch:
           return wrongAnswer(cpid, qid);
      }
      
      case textQuestion(qid,descr,replies):
        return (answer in replies) ? correctAnswer(cpid, qid) : wrongAnswer(cpid, qid, "");
 
      case tvQuestion(qkind, qdetails): {
        qid    = qdetails.name;
       	descr  = qdetails.descr;
        setup  = qdetails.setup;
        lstBefore = qdetails.lstBefore;
        lstAfter  = qdetails.lstAfter;
        cndBefore = qdetails.cndBefore;
        cndAfter  = qdetails.cndAfter;
        holeInLst = qdetails.holeInLst;
        holeInCnd = qdetails.holeInCnd;
        vars   = qdetails.vars;
        auxVars = qdetails.auxVars;
        rtype = qdetails.rtype;
        hint = qdetails.hint;
        
        println("qdetails = <qdetails>");
        
        VarEnv env = ();
        generatedVars = [];
        for(<name, tp> <- vars){
          env[name] = <parseType(evalType(params[name] + ";")), params[name]>;
          generatedVars += name;
	    }
  
	    for(<name, exp> <- auxVars){
          exp1 = subst(exp, env) + ";";
          println("exp1 = <exp1>");
          env[name] = <parseType("<evalType(setup + exp1)>"), "<eval(setup + exp1)>">;
        }
        
        lstBefore = subst(lstBefore, env);
	    lstAfter = subst(lstAfter, env);
	    cndBefore = subst(cndBefore, env);
	    cndAfter = subst(cndAfter, env);
          
        switch(qkind){
          case valueOfExpr(): {
	        try {
	            if(lstBefore + lstAfter == ""){
	              println("YES!");
	              if(holeInCnd){
	                 computedAnswer = eval(setup + (cndBefore + answer + cndAfter + ";"));
	                 if(computedAnswer == true)
	                   return correctAnswer(cpid, qid);
	                 wrongAnswer(cpid, qid, hint);
	              } else {
	                 println("YES2");
	                 computedAnswer = eval(setup + (cndBefore + ";"));
	                 givenAnswer = eval(setup + (answer + ";"));
	                 if(computedAnswer == givenAnswer)
	                   return correctAnswer(cpid, qid);
	                 return wrongAnswer(cpid, qid, "I expected <computedAnswer>.");
	               } 
	            }
	            validate = (holeInLst) ? lstBefore + answer + lstAfter + cndBefore	             
	                                     : ((holeInCnd) ? lstBefore + cndBefore + answer + cndAfter
	                                                    : lstBefore + cndBefore + "==" + answer);
	            
	            println("Evaluating validate: <validate>");
	            output =  shell(setup + validate);
	            println("result is <output>");
	            
	            a = size(output) -1;
	            while(a > 0 && startsWith(output[a], "cancelled") ||startsWith(output[a], "rascal"))
	               a -= 1;
	               
	            errors = [line | line <- output, /[Ee]rror/ := line];
	            
	            if(size(errors) == 0 && cndBefore == "")
	               return correctAnswer(cpid, qid);
	               
	            if(size(errors) == 0 && output[a] == "bool: true")
	              return correctAnswer(cpid, qid);
	            if(hint != ""){
	               return wrongAnswer(cpid, qid, "I expected <subst(hint, env)>.");
	            }
	            //if(!(holeInLst || holeInCnd)){
	           //    return wrongAnswer(cpid, qid, "I expected <eval(subst(cndBefore, env))>.");
	           // }  
	            return wrongAnswer(cpid, qid, "I have no expected answer for you.");
	          } catch:
	             return wrongAnswer(cpid, qid, "Something went wrong!");
	      }

          case typeOfExpr(): {
	          try {
	            if(lstBefore == ""){ // Type question without listing
	               answerType = answer;
	               expectedType = "";
	               errorMsg = "";
	               if(holeInCnd){
	                  validate = cndBefore + answer + cndAfter;
	                  println("Evaluating validate: <validate>");
	                  answerType = evalType(setup + validate);
	                  expectedType = toString(generateType(rtype, env));
	               } else
	                  expectedType = evalType(setup + cndBefore);
	                  
	               println("answerType is <answerType>");
	               println("expectedType is <expectedType>");
	               if(answerType == expectedType)
	              		return correctAnswer(cpid, qid);
	              errorMsg = "I expected the answer <expectedType> instead of <answerType>.";
	              if(!holeInCnd){
	                 try parseType(answer); catch: errorMsg = "I expected the answer <expectedType>; \"<answer>\" is not a legal Rascal type.";
	              }
	              return  wrongAnswer(cpid, qid, errorMsg);
	            } else {   // Type question with a listing
	              validate = (holeInLst) ? lstBefore + answer + lstAfter + cndBefore	             
	                                     : ((holeInCnd) ? lstBefore + cndBefore + answer + cndAfter
	                                                    : lstBefore + cndBefore);
	            
	              println("Evaluating validate: <validate>");
	              output =  shell(setup + validate);
	              println("result is <output>");
	              
	              a = size(output) -1;
	              while(a > 0 && startsWith(output[a], "cancelled") ||startsWith(output[a], "rascal"))
	                 a -= 1;
	                 
	              expectedType = toString(generateType(rtype, env));
	              
	              errors = [line | line <- output, /[Ee]rror/ := line];
	              println("errors = <errors>");
	               
	              if(size(errors) == 0 && /^<answerType:.*>:/ := output[a]){
	                 println("answerType = <answerType>, expectedType = <expectedType>, answer = <answer>");
	                 ok = ((holeInLst || holeInCnd) ? answerType : answer) == expectedType;
	                 if(ok)
	                    return correctAnswer(cpid, qid);
	                    
	                 errorMsg = "I expected the answer <expectedType> instead of <answerType>.";
	                 if(!holeInCnd){
	                    try parseType(answer); catch: errorMsg = "I expected the answer <expectedType>; \"<answer>\" is not a legal Rascal type.";
	                 }
	                 wrongAnswer(cpid, qid, errorMsg);
	              }
	              
	              errorMsg = "";
	              for(error <- errors){
	                   if(/Parse error/ := error)
	                      errorMsg = "There is a syntax error in your answer. ";
	              }
	              if(errorMsg == "" && size(errors) > 0)
	                 errorMsg = "There is an error in your answer. ";
	                 
	              errorMsg += (holeInLst) ? "I expected a value of type <expectedType>. "
	                                      : "I expected the answer <expectedType>. ";
	                                      
	              if(!(holeInCnd || holeInLst)){
	                 try parseType(answer); catch: errorMsg = "Note that \"<answer>\" is not a legal Rascal type.";
	              }
	            
	              return  wrongAnswer(cpid, qid, errorMsg);
	            }
	          } //catch SyntaxError(l): wrongAnswer(cpid, qid, "There is a syntax error in your answer.");
	            //catch e:  wrongAnswer(cpid, qid, "There is an error in your answer: <e>");
	            catch:
	             return wrongAnswer(cpid, qid, "Cannot assess your answer.");
	      }
	    }
      }
    }
    throw "Cannot validate answer: <qid>";
}

public str showCheat(ConceptName cpid, QuestionName qid, Question q, str expr){
   switch(q){
      case choiceQuestion(qid,descr,choices): {
        gcnt = 0;
        for(ch <- choices)
           if(good(txt) := ch)
           	  gcnt += 1;
        plural = (gcnt > 1) ? "s" : "";
        return cheatAnswer(cpid, qid, "The expected answer<plural>: <for(ch <- choices){><(good(txt) := ch)?txt:""> <}>");
      }
      
      case textQuestion(qid,descr,replies): {
        plural = (size(replies) > 1) ? "s" : "";
        return cheatAnswer(cpid, qid, "The expected answer<plural>: <for(r <- replies){><r> <}>");
      }
        
      case typeQuestion(qid,descr,setup,tp):
        try {
          expected = evalType(expr);
          return cheatAnswer(cpid, qid, "The expected answer: <expected>");
        } catch:
        	cheatAnswer(cpid, qid, "Error while coputing the cheat");
        
      case exprQuestion(qid,descr,setup,tp): {
          try {
            expected = eval(expr);
            return cheatAnswer(cpid, qid, "The expected answer: <expected>");
          } catch:
             return cheatAnswer(cpid, qid, "Error while computing the cheat");
        }
        case exprTypeQuestion(qid,descr,setup,tp): {
          try {
            expected = evalType(expr);
            return cheatAnswer(cpid, qid, "The expected answer: <expected>");
          } catch:
             return cheatAnswer(cpid, qid, "Error while computing the cheat");
        }
    }
    throw "Cannot give cheat for: <qid>";

}

public str showAnother(ConceptName cpid, QuestionName qid, Question q){
    return XMLResponses(("concept" : cpid, "exercise" : qid, "another" : showQuestion(cpid, q)));
}

public str cheatAnswer(ConceptName cpid, QuestionName qid, str cheat){
    return XMLResponses(("concept" : cpid, "exercise" : qid, "validation" : "true", "feedback" : cheat));
}

public list[str] positiveFeedback = [
"Good!",
"Go on like this!",
"I knew you could make this one!",
"You are making good progress!",
"Well done!",
"Yes!",
"Correct!",
"You are becoming a pro!",
"You are becoming an expert!",
"You are becoming a specialist!",
"Excellent!",
"Better and better!",
"Another one down!",
"You are earning a place in the top ten!",
"Learning is fun, right?"
];

public list[str] negativeFeedback = [
"A pity!",
"A shame!",
"Try another question!",
"I know you can do better.",
"Nope!",
"I am suffering with you :-(",
"Give it another try!",
"With some more practice you will do better!",
"Other people mastered this, and you can do even better!",
"It is the journey that counts!",
"Learning is fun, right?",
"After climbing the hill, the view will be excellent.",
"Hard work will be rewarded!"
];

public str correctAnswer(ConceptName cpid, QuestionName qid){
    badAnswer -= qid;
    goodAnswer += qid;
    feedback = (arbInt(100) < 25) ? getOneFrom(positiveFeedback) : "";
    return XMLResponses(("concept" : cpid, "exercise" : qid, "validation" : "true", "feedback" : feedback));
}

public str wrongAnswer(ConceptName cpid, QuestionName qid, str explanation){
    badAnswer += qid;
    goodAnswer -= qid;
    feedback = explanation + ((arbInt(100) < 25) ? (" " + getOneFrom(negativeFeedback)) : "");
	return  XMLResponses(("concept" : cpid, "exercise" : qid, "validation" : "false", "feedback" : feedback));
}

public str XMLResponses(map[str,str] values){
    return "\<responses\><for(field <- values){>\<response id=\"<field>\"\><escapeForHtml(values[field])>\</response\><}>\</responses\>";
}

public str escapeForHtml(str txt){
  return
    visit(txt){
      case /^\</ => "&lt;"
      case /^\>/ => "&gt;"
      case /^"/ => "&quot;"
      case /^&/ => "&amp;"
    }
}
