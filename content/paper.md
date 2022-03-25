# Introduction

When software engineers look at the source code of an existing application, they want to understand how the program was implemented technically. They do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g., during onboarding of a new team member) or, more often, because someone reported an unexpected application behavior (e.g., the program crashed). Inspecting source code at runtime is commonly known as "debugging" [@IEEE_Glossary]. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. They then (ii) instrument the program using appropriate techniques to prove their hypothesis. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

```{.include}
content/figures/debugging-process.tex
```

The most basic debugging technique for instrumentation and testing is manually adding print statements to the source code: They generate execution logs when placed across the program's code and allow to reconstruct its runtime behavior. However, the number of generated log entries increases, the required amount of work to analyze the logs gets out of hand quickly. This is why specialized debugging utilities provide tools to interact with a program at runtime: After interrupting program execution with a breakpoint, they allow engineers to inspect stack frames, inspect and modify variables, step through successive source code statements, or resume program execution eventually. These utilities work best with imperative or control-flow-oriented programming languages since they interact with statements and stack frames of the debugged program.

Modern IDEs enable software engineers to debug programs, no matter what programming language they are implemented with, using one generalized user interface (UI). The result is a unified user experience (UX) where debugging support is only a click away.

However, by adopting control-flow-oriented debugging utilities into their workflows, software engineers face a new problem when working with reactive programming (RP). Salvaneschi et al. [@Salvaneschi_Mezini_2016] described this shortcoming of traditional debuggers when confronted with RP and coined the concept of _RP Debugging_. Later, Banken et al. [@Banken_Meijer_Gousios_2018] proposed a solution for debugging RxJS RP programs in an external visualizer utility.

Alabor et al. [@Alabor_Stolze_2020] examined the RP debugging habits of software engineers in an observational study. They replicated the observation by Salvaneschi et al. and observed that even engineers aware of RP debugging tools did not use them. Instead, these engineers used manual print statements.

\vspace{3mm}

Within this paper, we are going to present two contributions to the field of RP debugging:

\vspace{1mm}

1. _Operator log points_ are a novel utility for debugging RP programs. They make manual print statements obsolete by providing specialized log points for RP applications.\vspace{1mm}

2. By implementing operator log points in _RxJS Debugging for Visual Studio Code_, an extension for Microsoft Visual Studio Code^[[https://code.visualstudio.com](https://code.visualstudio.com)] (vscode), we provide a proof by existence for the feasibility of a ready-to-hand RP debugging utility. Software engineers can debug RxJS programs without learning new UX patterns or additional setup effort.

\vspace{3mm}

Before we do a deep-dive on the functionality of operator log points in Section [4](#sec:implementation), we present an example for the primary challenge of RP debugging in Section [2](#sec:challenge) and discuss related work in Section [3](#sec:background). Next, we give an overview of performed usability inspections and validations in Section [5](#sec:ux). Finally, we consider threats to validity regarding the usability tests in Section [6](#sec:threats_to_validity) and introduce topics for future work in Section [7](#sec:future_work).

# RP Debugging: The Hard Way {#sec:challenge}

A primary characteristic of RP is the paradigm shift away from imperatively formulated, control-flow-oriented code (see Listing [1](#lst:imperative)) to declarative, data-flow-focused source code [@Salvaneschi_Mezini_2016]. Instead of instructing the computer how to do what, i.e., one step after another, we use RP abstractions to describe the transformation of a continuous flow of data.

```{
  caption="Basic example of imperative-style/control-flow-oriented programming in JavaScript: Multiply integers between 0 and 4 for every value that is smaller than 4 and call reportValue with the result."
  label=imperative
  float=t
  .Typescript
}
import reportValue from './reporter';

for (let i = 0; i < 5; i++) {
  if (i < 4) {
    reportValue(i * 2);
  }
}
```

RxJS implements reactive sources with _Observables_. An observable generates five types of life cycle events: Once a consumer (i) _subscribes_ to an observable, the observable starts to (ii) _emit_ values, (iii) _completes_ (e.g., when a network request has been completed), fails with an (iv) _error_, or may get (v) _unsubscribed_. Engineers use _Operators_ to transform these events on their way through the data-flow graph. An operator modifies values, composes other observables, or changes how life cycle events get forwarded (e.g., catch an error and emit an empty value instead). Listing [2](#lst:rp) shows an example of a source observable, two operators, and one consumer.

```{
  caption="Basic RP example implemented with RxJS in JavaScript: Generate a data-flow of integers from 0 to 4, skip values equal or larger then 4, multiply these values by 2 and call reportValue with each resulting value."
  label=rp
  float=t
  .Typescript
}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe( // Observable with ints 0..4
  filter(i => i < 4),   // Operator omitting 4
  map(i => i * 2),      // Operator multiplying by 2
).subscribe(reportValue)
```

Traditional debuggers reach their limitations when facing data-flow-oriented code: While we can navigate through the successive iterations of the _for_ loop in Listing [1](#lst:imperative) using the step controls of the debugger, this is not possible for the transformations described in Listing [2](#lst:rp). Assuming we set a breakpoint within the lambda function passed to _filter_ on Line 6, stepping over to the next statement will not lead to the lambda of _map_ on Line 7 as one might expect. Instead, the debugger continues in the internal implementations of _filter_, part of the RxJS RP runtime. With a deeper understanding of the difference between control- and data-flow-oriented programming, this might look plausible. However, previous research [@Salvaneschi_Mezini_2016; @Banken_Meijer_Gousios_2018; @Alabor_Stolze_2020] revealed that software engineers expect different behavior from the debugging tools they have at hand. As a direct consequence, engineers fall back to the problematic debugging technique of adding manual print statements, as exemplified in Listing [3](#lst:rp-print) on the next page.

```{
  caption="Manually added print statements on Lines 6, 8 and 10 to debug a data-flow implemented with RxJS in JavaScript."
  label=rp-print
  float=t
  .Typescript
}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map, tap } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe(
  tap(console.log),     // <-- Print Statement
  filter(i => i < 4),
  tap(console.log),     // <-- Print Statement
  map(i => i * 2),
  tap(console.log),     // <-- Print Statement
).subscribe(reportValue)
```

# Related Work {#sec:background}

Salvaneschi et al. [@Salvaneschi_Mezini_2016] identified the divergence between a control-flow-oriented debugger's expected and actual behavior as one of their key motivations for RP debugging. The stack-based runtime model of control-flow-oriented debuggers does not match the software engineers' data-flow-oriented mental model of the program they are debugging. Because the debugger has a "lack of abstraction," it cannot interpret high-level RP abstractions and works on the low-level implementations of the RP runtime extension instead. Salvaneschi et al. proposed _Reactive Inspector_ [@Salvaneschi_Hintz_Mezini_2014], the first specialized RP debugging solution for RP programs implemented with REScala, an RP extension for the Scala programming language. Integrated with the Eclipse IDE, the utility provides a wide range of RP debugging functionalities like the visualization of data-flow graphs and the information that traverses through them. Reactive breakpoints allow to interrupt program execution once a graph node reevaluates its value.

Since then, RP has gained more traction across various fields of software engineering. With a shared vision on how to surface RP abstractions at the API level, _ReactiveX_^[[http://reactivex.io/](http://reactivex.io/)] consolidated numerous projects under one open-source organization. Together, its members provide RP extensions for many of today's mainstream programming languages like Java, C#, and Swift. For the development of JavaScript-based applications, software engineers can rely on RxJS^[[https://rxjs.dev](https://rxjs.dev)]. Angular by Google is one of the more popular adopters of this library and uses RxJS to model asynchronous operations like fetching data in web frontend applications.

Two years after Salvaneschi et al. proposed RP Debugging, Banken et al. [@Banken_Meijer_Gousios_2018] showed that debugging RxJS-based RP programs is quite similar to REScala-based ones. They were able to categorize the debugging motivations of their study participants into four main, overarching themes. These directly correlate with the debugging issues identified by Salvaneschi et al. earlier, as we show in Table [1](#tbl:salvaneschi-vs-banken).

```{.include}
content/tables/table-salvaneschi-vs-banken.tex
```

Banken et al. provided a debugger in the form of an isolated visualizer: _RxFiddle_. The browser-based application visualizes the runtime behavior of an RxJS program in two dimensions: A central (i) data-flow graph shows which elements in the graph interact with each other, and a dynamic (ii) marble diagram[^1] represents the processed values over time.

[^1]: Marble diagrams are a visualization technique used throughout the ReactiveX community to graphically describe the behavior of observable-based data-flow graphs. A marble represents a life cycle event, e.g., an emitted value. Multiple marbles are arranged on a thread from left to right, indicating the point in time when the respective life cycle event happened. See https://rxmarbles.com/ for examples.

Both Salvaneschi et al. and Banken et al. suggested technical architectures for RP debugging systems. Both suggestions can be summarized as distributed systems consisting of two main components: The (i) RP runtime is instrumented to produce debugging-relevant events (e.g., value emitted or graph node created). These events get processed by the (ii) debugger, which provides a UI to inspect the RP program's state.

Another two years after Banken et al. published their work, Alabor et al. [@Alabor_Stolze_2020] examined the state of RxJS RP debugging. Software engineers still struggled to use appropriate tools to debug RxJS programs according to the interviews they conducted. The authors performed an observational study and found instances of engineers who knew about RP-specific debugging tools but abstained from using them during the experiment. They credited this circumstance to the fact that the IDEs of their subjects did not provide suitable RP debugging utilities ready-to-hand.

Alabor et al. conclude that knowing the correct RP debugging utility (e.g., _RxFiddle_) is not enough. The barrier to using such utilities must be minimized. I.e., RP debugging utilities must be fully integrated into the IDE to live up to their full potential, so using them is ideally only an engineer's keypress away and adheres to accustomed, known UX patterns.

# An RxJS Debugger Ready-to-Hand {#sec:implementation}

We translated these findings into the central principle for the design of our RP debugger for RxJS: _Ready-to-hand_. Software engineers should always have the proper debugging tool available, no matter what programming paradigm they are currently working with. Further, this tool should integrate with the engineer's workflow seamlessly.

## Operator Log Points

Operator log points combine the concept of log points as known from control-flow-oriented debuggers with live _probes_, formerly proposed by McDirmid [@McDirmid_2013]^[As a matter of fact, operator log points were originally called *operator probes*, but got renamed after initial confusion with our test users.] for RP programs. They display life cycle events produced by an RxJS operator directly within the source code editor.

Possible operator log points are suggested ready-to-hand through an icon annotation within the code editor, next to the respective operator. While the software engineer instruments the source code to prove their debugging hypothesis, they can enable a log point by hovering the mouse pointer over its associated annotation and selecting the _Add Operator Log Point_ action (see Figure [2](#fig:operator-log-points)). When ready to test their hypothesis, the engineer starts the RxJS program using the built-in JavaScript debugger; no extra effort is required. Once the program is running, each enabled operator log point displays the life cycle events together with the source code that produced them. Engineers are free to enable or disable additional log points during the debugging session; the life cycle event display will adapt accordingly.

Once finished debugging, the software engineer stops the program. Contrary to manual print statements, no clean-up work is necessary afterward since operator log points do not require any code modifications.

![*RxJS Debugging for vscode* used to debug code from Listing [2](#lst:rp). A diamond icon indicates operator log points: A grey outline represents a suggested log point (Line 7), a filled, red diamond an enabled log point (Line 8). The source code editor shows life cycle events at the end of the respective line (Line 8, "Unsubscribe"). Log points are managed by hovering the respective icon and selecting the appropriate action.](./content/figures/operator-log-points.png)

## Suggesting a Log Point

Log points for operators are automatically suggested while the software engineer edits the source code of an RxJS program. To interpret the programs code semantically, the debugger extension leverages on the TypeScript^[TypeScript is a strongly typed programming language that compiles to JavaScript [https://www.typescriptlang.org/](https://www.typescriptlang.org/)] programming language toolchain.

We use the TypeScript parser to continuously evaluate source code, which results in an abstract syntax tree (AST). Along with the semantical structure of the program, the AST contains type and positional information for every parsed token. The extension processes the type information to detect all present RxJS operator functions. For every operator function found, the positional information allows to annotate the relevant source code in the editor with an icon.

## Architecture

The technical architecture of _RxJS Debugging for vscode_ (see Figure [4](#fig:architecture)) is a refined version of the system proposed by Banken et al. [@Banken_Meijer_Gousios_2018].

```{.include}
content/figures/architecture.tex
```

JavaScript virtual machines (VM) like V8 (used in Google Chrome or Node.js) or SpiderMonkey (used in Mozilla Firefox) implement the Chrome DevTools Protocol (CDP)^[[https://chromedevtools.github.io/devtools-protocol/](https://chromedevtools.github.io/devtools-protocol/)]. Debugging tools like vscode's built-in JavaScript debugger use CDP to connect and debug JavaScript programs. RxFiddle by Banken et al. [@Banken_Meijer_Gousios_2018] uses WebSockets to exchange relevant data. We leverage the CDP connection established by the vscode's JavaScript debugger, making the system more robust since we do not need to maintain an additional channel for debugger communication.

# Usability Inspection and Validation {#sec:ux}

We followed a User-Centered Design (UCD) [@Goodwin_2009] approach in three iterations to conceptualize and implement our debugging utility. The relevant methods we applied helped us to keep our efforts aligned with our main goal: To establish a debugging utility that is ready to hand and does not requiry any extra learning or setup procedures.

After sketching a rough proof of concept (PoC) in the first step, we performed a cognitive walkthrough [@Wharton_Rieman_Clayton_Polson_1994] to validate our idea of replacing manual print statements with operator log points. The resulting data helped us to build a prototype of the extension. Next, we used this prototype to conduct a moderated remote usability test with three subjects. This allowed us to uncover pitfalls in the UX concept and find misconceptions early in the development process. Finally, we used the results of these sessions for further refinement. We completed the first minor version of the RxJS RP debugger, which we released to the Visual Studio Marketplace in May 2021^[https://marketplace.visualstudio.com/items?itemName=manuelalabor.rxjs-debugging-for-vs-code].

We used the test cases created by Alabor et al. [@Alabor_Stolze_2020] for both the cognitive walkthrough and the remote usability test.

## Cognitive Walkthrough

We concluded the first iteration of our development process with a PoC demonstrating the basic concept of operator log points.

Looking for an informal, expert-driven usability inspection method [@Nielsen_1994], we found the cognitive walkthrough [@Wharton_Rieman_Clayton_Polson_1994] to be a good fit in this early stage of development. We prepared the profile of a typical user for the RP debugger as input to the inspection. Based on this profile and the debugging process by Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013], we created the action sequence available in Table [2](#tbl:cognitive-walkthrough). We performed the walkthrough using the _Problem 1_ web application by Alabor et al. [@Alabor_Stolze_2020].

```{.include}
content/tables/steps-cognitive-walkthrough.tex
```

The cognitive walkthrough revealed six usability issues, as summarized in Table [3](#tbl:cognitive-walkthrough-issues). The full inspection report, including the complete user profile, is available on Github^[https://github.com/swissmanu/mse-paper-rxjs-debugger].

```{.include}
content/tables/issues-cognitive-walkthrough.tex
```

## Moderated Remote Usability Test

After the initial validation using the cognitive walkthrough, we completed the development of the refined prototype, ready to test with real users.

### Study Design

"Think aloud" tests for high functionality systems benefit from at least five test subjects or more [@Nielsen_Participants_1994]. The feature spectrum of the RP debugger prototype is small; hence the probability of finding major usability issues with a smaller subject population is high. Therefore, we decided to work with three individual subjects for our study.

Participants, recruited via Twitter, were required to have worked with RxJS during the past year and use vscode as their primary IDE. We sent out a PDF containing a short briefing and a prototype description a week before the actual test session. The briefing contained information about software requirements (Zoom, Node.js, npm/Yarn, and vscode) and details on what the subjects might encounter during their test session. Here, we emphasized the importance of "think aloud" [@Boren_Ramey_2000; @Norgaard_Hornbaek_2006], the practice of continuously verbalizing thoughts without reasoning about them.

### Study Execution

At the start of a test session, we provided each participant with a ZIP file^[[https://github.com/swissmanu/mse-pa2-usability-test](https://github.com/swissmanu/mse-pa2-usability-test)] containing the _Problem 2_ web application by Alabor et al. [@Alabor_Stolze_2020] and the packaged version of the debugger extension prototype^[[https://github.com/swissmanu/mse-pa2-spike-vscode](https://github.com/swissmanu/mse-pa2-spike-vscode)]. While the subject prepared their development environment, we started the video, screen, and audio recording with their consent. Also, we gave a scripted introduction to the code base they just received.

The participants had 25 minutes to resolve as many bugs as possible using the debugger prototype. Rather than tracking each subject's success rate of fixed defects, we emphasized detecting usability issues in their workflow instead.

### Study Evaluation

One participant could not get the prototype extension up and running on their system, which means we had only two valid data sets for further evaluation after study execution. We categorized the observed usability issues by debugging process phase (i.e., gather context, instrument hypothesis, and test hypothesis) and task (e.g., "Setup Environment", "Manage Log Points", or "Interpret Log"). From a total of 10 issues, we observed four being a problem for both remaining study subjects. Thus we prioritized them as "major". The full usability issue report is available on Github^[https://github.com/swissmanu/mse-paper-rxjs-debugger]. Table [4](#tbl:issues-usability-test) presents the four major issues.

```{.include}
content/tables/issues-usability-test.tex
```

## Utilization

### Application of Results

We applied the results from the cognitive walkthrough and the usability tests to refine and complete the RxJS RP debugger presented in Section [4](#sec:implementation). For example, both the PoC and the prototype had an extra view for displaying the output of a log point, visually disconnecting them from each other. We classified this circumstance as prone to confuse the user during the walkthrough but did not change the prototype yet. The usability tests with real subjects confirmed our suspicion, however. Because of this, we changed the UI for the final, current version and introduced the inline display for log point output directly in the code editor. Another example of an improvement is how the debugger suggests operator log points: The subjects were unaware that suggested log points were available via the code action menu, even though this is an established UX pattern in vscode. Therefore, we removed the suggestions from this menu and introduced the diamond-shaped indicator icon, which is always visible.

### Concept Verification

The applied inspection and verification methods, in combination with the practical implementation of the debugger, deliver the existence proof for the feasibility of a ready-to-hand RP debugging utility. Even though the usability test revealed four major usability issues, we successfully verified that operator log points resolve the problems previously identified by Alabor et al. [@Alabor_Stolze_2020].

# Threats to Validity {#sec:threats_to_validity}

The results of the usability test are subject to the following threats and limitations:

## Internal Validity

We performed the usability test in an uncontrolled, remote environment, and all participants used their own computers and software installations. The downside of this is the early failure of one subject, which could not get the prototype extension running on their system resulting in an invalid data set. Even though we could have prevented this situation in a controlled lab environment, we consciously decided to take this risk and, in turn, get more realistic results from users working in the context of their accustomed development environment.

## External Validity

Due to the circumstance that one study participant could not set up the prototype extension, we ended up having only two valid data sets after the remote usability test. Two test subjects should have allowed us to find around 50% of all usability issues present [@Nielsen_Landauer_1993]. Because the two remaining subjects share four of 10 issues, we are confident that we identified the most critical usability problems nonetheless.

## Construct Validity

We carefully moderated the test session once test subjects fell silent for more than 10 seconds and reminded them to "think aloud". Even though the participants told us that "speaking to themselves" created an unfamiliar environment for them, we expect the moderation techniques used [@Boren_Ramey_2000] to minimize any influences on the results.

# Future Work {#sec:future_work}

There are several ways how future work can contribute to the efforts presented in this paper.

## Field Test

Version 0.1.2 of _RxJS Debugging for vscode_ can debug RxJS programs running in the Node.js JavaScript VM. The major release 1.0.0 generalizes this solution further and brings operator log points to RxJS applications running in web browsers. Thus, we expect installations of the debugger to increase further since more software engineers can benefit from its features.

We see the opportunity for a comprehensive field test on how engineers use the novel RP debugger once its next iteration is available. Usage statistics provided through the planned analytics reporting module will prove helpful in these regards.

## Visualizer Component

Banken et al. [@Banken_Meijer_Gousios_2018] proposed visualization techniques for RxJS data-flow graphs in _RxFiddle_. The debugging utility we presented in this paper benefits from the integration of such a visualizer. The graphical representation of an observable graph helps novice engineers to understand RxJS concepts better, and experienced engineers get a new angle on the composition of multiple observables when debugging.

## Record and Replay

A software engineer can record the behavior of a RP program and replay that data independently as many times as they wish later [@OCallahan_Jones_Froyd_Huey_Noll_Partush_2017]. Such a function would allow two things: During debugging, the engineer can rerun a recorded failure scenario without depending on external systems like remote APIs. Further, recorded data might be used for regression testing to verify that a modified program still works as expected [@Perez_Nilsson_2017].

## Time Travel Debugging

Contrary to regular control-flow-oriented debuggers, omniscient [@Pothier_Tanter_2009], or _time travel_ debuggers cannot only step forward but also backward in time. This is because they rely on recorded data rather than a currently running program. Once there is a way to record, store and replay debugging data as suggested before, time travel debugging is a possible next step. Software engineers can then manually navigate through recorded data and observe how individual system parts react to the stimuli.

# Conclusion {#sec:conclusion}

We presented _operator log points_ as a novel debugging utility for programs implemented using reactive programming in this paper. With _RxJS Debugging for vscode_, we demonstrated how operator log points replace manual print statements for RxJS-based programs. We developed the debugger using a user-centered design process facilitating usability inspection and validation methods, which allowed us to identify and resolve four major usability issues. In addition, we successfully verified that the proposed utility fulfills the requirement of readiness-to-hand, i.e., that it integrates seamlessly with software engineers' daily workflows and does not require additional learning or setup effort.
