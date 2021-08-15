# Introduction

When software engineers look at the source code of an existing application, they want to learn about how the program was implemented technically. They might do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g. during onboarding of a new team member) or, more often, because someone reported an unexpected behavior of the application (e.g. the program crashed). This kind of work is commonly known as "debugging" [@IEEE_Glossary]. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three concrete steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. With the goal to prove this hypothesis, the engineer (ii) instruments the program using appropriate techniques. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

```{.include}
content/figures/debugging-process.tex
```

The most basic debugging technique for instrumentation and testing are manually added print statements to the source code: They generate execution logs when placed  across the programs code and allow the reconstruction of the programs runtime behavior. Once the number of generated log entries increases, the required amount of work to analyze the logs gets out of hand quickly. This is why specialized debugging utilities provide tools to interact with a program at runtime: After interrupting program execution with a breakpoint, they allow engineers to inspect stack frames, inspect and modify variables, step through successive source code statements, or resume program execution eventually. These utilities work best with imperative, or control-flow oriented programming languages since they interact with the debugged program on a statement and stack frame level.

Modern IDEs enable software engineers to debug programs, no matter what programming language they are implemented with, using one, generalized user interface (UI). The result is a unified user experience (UX) where the supposed correct debugger is only a click away. Software engineers have accepted these debuggers as common practice according to Alabor et al. [@Alabor_Stolze_2020]. By integrating imperative debuggers in their workflows, software engineers face a new problem when working with reactive programming (RP) though. Alabor et al. highlight that multiple of their studys participants intuitively expected their debuggers step controls to work on the RP data-flow graph and were surprised that they did not. This discrepancy between expected and actual behavior of the debugger lets engineers fall back to adding manual print statements.

The circumstance of debugging RP programs with the wrong debugging utilities is not new: Salvaneschi et al. described the shortcoming of traditional debuggers when confronted with RP in their paper and coined the concept of *RP Debugging* [@Salvaneschi_Mezini_2016]. Later, Banken et al. [@Banken_Meijer_Gousios_2018] researched on a possible solution for debugging RxJS RP programs using an external visualizer sandbox named *RxFiddle*. However, software engineers still do not have the right tools at hand today when needing them most, as Alabor et al. state.

Within this paper, we are going to present two concrete contributions to the field of RxJS RP debugging:

1. With *RxJS Debugging for Visual Studio Code*, an extension for Microsoft Visual Studio Code^[https://code.visualstudio.com] (vscode), engineers building RxJS applications get access to a powerful RP debugging tool. It integrates tightly with the IDE itself and requires no extra efforts to debug an RP program.

2. A refined architecture for RxJS RP debuggers leveraging on the *Chrome DevTools Protocol*^[https://chromedevtools.github.io/devtools-protocol/] (CDP) for message-based communication between individual system components.

*TODO Rewrite Before we do a deep-dive on the extensions functionality in Section [4](#sec:implementation), we will give an example for the main challenge of RP debugging in Section [2](#sec:challenge). We discuss related work in Section [3](#sec:background). Before we come to our conclusion in Section [8](#sec:conclusion), we will consider potential threats to validity in Section [6](#sec:threats_to_validity) and give an overview on potential follow-up topics, research-wise as well as practical, in Section [7](#sec:future_work).*

# RP Debugging: The Hard Way {#sec:challenge}

One of the main characteristics of RP is the paradigm shift away from imperatively formulated, control-flow oriented code (see Listing [1](#lst:imperative)), over to declarative, data-flow focused source code [@Salvaneschi_Mezini_2016]. Instead of instructing the program how to do what, i.e. one step after another, we use RP abstractions to describe the transformation of a continuous flow of data as shown in Listing [2](#lst:rp).

```{caption="Basic example of imperative-style/control-flow oriented programming in TypeScript: Multiply integers between 0 and 4 for every value that is smaller than 4 and call reportValue with the result." label=imperative .Typescript}
import reportValue from './reporter';

for (let i = 0; i < 5; i++) {
  if (i < 4) {
    reportValue(i * 2);
  }
}
```


```{caption="Basic RP example implemented with RxJS in TypeScript: Generate a data-flow of integers from 0 to 4, skip values equal or larger then 4, multiply these values by 2 and call reportValue with each resulting value." label=rp .Typescript}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe( // Flow of integers 0..4
  filter(i => i < 4),   // Omit 4
  map(i => i * 2),      // Multiply with 2
).subscribe(reportValue)
```

Traditional debuggers reach their limitations when facing data-flow oriented code: While we can navigate through the successive iterations of the *for* loop in Listing [1](#lst:imperative) using their step controls, this is not possible for the transformations described in Listing [2](#lst:rp): Assuming we set a breakpoint within the lambda function passed to *filter* on Line 6, stepping over to the next statement will not lead to the lambda of *map* on Line 7 as one might expect. Instead, the debugger will continue in the internal implementations of *filter*, which is part of the RxJS RP runtime environment. With a deeper understanding of what the difference between control- and data-flow oriented programing is, this might look plausible. Alabor et al. showed however that software engineers expect a different behavior from the debugging tools they have at hand [@Alabor_Stolze_2020]. As a direct consequence, engineers fall back to the archaic debugging technique of adding manual print statements, as exemplified in Listing [3](#lst:rp-print), Alabor et al. state further.

```{caption="Manually added print statements on Lines 6, 8 and 10 to debug a data-flow implemented with RxJS in TypeScript." label=rp-print .Typescript}
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

This debugging technique is time consuming and cumbersome: The more print statements are added, the more log entries get generated, which in turn are harder to analyze and interpret. The print statements might further reside in the source code after the engineer finished with their debugging activities. This results in production artifacts containing irrelevant code or even newly introduced bugs if the engineers miss to clean up their instrumented code carefully.

# Related Work {#sec:background}

Salvaneschi et al. [@Salvaneschi_Mezini_2016] identified the divergence between expected and actual behavior of a control-flow oriented debugger as one of their key motivations for RP debugging: The stack-based runtime model of control-flow oriented debuggers does not match the software engineers data-flow oriented mental model of the program they are debugging. This is because the debugger has a "lack of abstractions"; it cannot interpret high-level RP abstractions and works on the low-level implementations of the regarding RP runtime environment instead. The group proposed the first specialized RP debugging solution for RP programs implemented with REScala [@Salvaneschi_Hintz_Mezini_2014], a RP runtime for the Scala^[https://scala-lang.org/] programming language. Integrated in the Eclipse IDE, the utilities provide a wide range of RP debugging functionalities like the visualization of data-flow graphs and the information that traverses through them. Reactive breakpoints allow further to interrupt program execution once a graph node re-evalutes its value.

Since then, RP gained more traction across various fields of software engineering. With a shared vision on how to surface RP abstractions on API level, *ReactiveX*^[http://reactivex.io/] consolidated numerous projects under one open source organization. Together, its members provide RP runtime environments for many of todays mainstream programming languages like Java, C#, or Swift. For the development of JavaScript-based applications, software engineers can rely on RxJS^[https://rxjs.dev]. One of the more popular adopters of this library is Google Angular^[https://angular.io/], a framework to develop web frontend applications, where it is used to model asynchronous operations like fetching data.

Two years after Salvaneschi et al. proposed RP Debugging, Banken et al. [@Banken_Meijer_Gousios_2018] showed in their paper that debugging RxJS-based RP programs is not that different from REScala-based ones. They were able to categorize the debugging motivations of their study participants into four main, overarching themes. These can be put into direct correlation with the debugging issues identified by Salvaneschi et al. earlier as we show in Table [1](#tbl:salvaneschi-vs-banken).

```{.include}
content/tables/table-salvaneschi-vs-banken.tex
```

The authors further provided a debugger in form of an isolated visualizer sandbox: *RxFiddle*. The browser-based application executes an RxJS program and visualize its runtime behavior in two dimensions: A central (i) data-flow graph shows which elements in the graph interact with each other and a dynamic (ii) marble diagram[^1] represents the values which were processed by the graph over time.

[^1]: Marble diagrams are a visualization technique used throughout the ReactiveX community to describe the behavior of a node in a data-flow graph graphically. A marble represents a value emitted by a graph node. Marbles are arranged on a thread from left to right, indicating the point in time when their value was emitted. See https://rxmarbles.com/ for more examples.

Both Banken et al. and Salvaneschi et al. suggested technical architectures for RP debugging systems. Both suggestions can be summarized as distributed systems consisting of two main components: The (i) instrumented RP runtime environment is augmented to produce debugging-relevant events (e.g. value emitted or graph node created). These events get processed by the actual (ii) debugger which provides a UI to inspect the RP programs state eventually.

Another two years after Banken et al. published their work, Alabor et al. [@Alabor_Stolze_2020] examined the state of RxJS RP debugging. According to their research, software engineers struggle to use appropriate tools to debug RxJS programs. The observational study the authors conducted produced the key finding of their work: Even though their subjects stated to know about suitable RP debugging utilities, none of them used such tools during the study. Alabor et al. credited this circumstance to the fact that their participants IDEs did not provide suitable RP debugging utilities right at hand.

Alabor et al. conclude that knowing about the correct RP debugging utility (e.g. *RxFiddle*) is not enough. The barrier to use such utilities must be minimized; i.e. in order to live up to their full potential, RP debugging utilities must be fully integrated into the IDE so using them is ideally only an engineers key press away and adheres to accustomed UX patterns known by them.

# Readiness-to-hand: An RxJS RP Debugger {#sec:implementation}

> *RxJS Debugger for vscode, the tool presente din this paper, achieves "readiness-to-hand" for engineers by providing following features:*

We translated these findings into the central principle for the design of our RP debugger for RxJS: *Readiness-to-hand*. Software engineers should always have the proper debugging tool ready, no matter what type of program they are currently confronted with. Further, this tool should integrate with the engineers workflow seamlessly.

## Features

We made manual print statements for debugging RxJS RP programs obsolete by providing a better alternative with *RxJS Debugging for vscode*. For this, we implemented *Operator Log Points*, a similar tool to *probes* as proposed by McDirmid [@McDirmid_2013] for live programming environments. The extension suggests a log point for every operator function detected. The engineer may enable such a log point by hovering the mouse pointer over its icon and selecting the *Add Operator Log Point* action (see Figure [2](#fig:operator-log-points)). Log point suggestions are generated by continuously parsing the source code of the current editor. The extension evaluates the resulting AST in order to detect operators passed to the *pipe* function of an observable[^2].

[^2]: An RxJS *Observable* is an abstraction of a reactive source. Once a consumer *subscribes* the source, the source pushes/*emits* values, *completes* (e.g. when a network request has completed), fails with an *error*, or may get *unsubscribed* from the consumer. These are the five main life cycle events engineers are interested in when debugging an observable. An operators is a node in the materialized data-flow graph. An operator transforms emitted values or composes multiple observables.

Once the software engineer starts the RP program with vscodes built-in JavaScript debugger, our extension displays life cycle events for all enabled log points inline with the source code which produced the event. Engineers are free to enable or disable additional log points during the debugging session.

![*RxJS Debugging for vscode* used to debug code from Listing [2](#lst:rp). A diamond icon indicates operator log points: A grey outline represents a suggested log point (Line 7), a filled, red diamond an enabled log point (Line 8). Life cycle event logs are shown at the end of the respective line in the source code editor (Line 8, "Unsubscribe"). Log points are managed by hovering a log point icon and selecting the appropriate action.](./content/figures/operator-log-points.png)

The result is a strikingly simple, yet effective way to uncover and trace the runtime behavior of RxJS observables. Hence, this simplicity is possible because of a coordinated, distributed system behind the curtains.

## Architecture

The technical architecture of *RxJS Debugging for vscode* is a refined version of the system proposed by Banken et al. [@Banken_Meijer_Gousios_2018] and shares its fundamental components as shown in Figure [4](#fig:architecture): The *Telemetry* component runs in the same process as the debugged RP program augmenting it. Telemetry gathers and relays life cycle events to the debugger extension component running in the vscode process.

```{.include}
content/figures/architecture.tex
```

Contrary to *RxFiddle*, our implementation uses a different way to connect these two components. Where the solution by Banken et al. uses WebSockets to exchange messages, we leverage on the CDP[^3] connection, established by the generic JavaScript debugger, instead[^4]. We decided for this approach because it gives us two benefits out of the box: (i) UX-wise, the software engineer does not to decide "how" they want to debug their program (i.e. traditionally control-flow oriented or RP, data-flow oriented). They start debugging using familiar commands and RP specific debugging capabilities are provided once available without additional effort. (ii) Technically, we do not need to care for "where" the RP program the user wants to debug is running (e.g. locally in a browser or in a Node.js process on a remote computer) since this is taken care for by the generic JavaScript debugger. The result is a robust, less complex system since we do not need to maintain an additional side channel for RP debugging communication.

[^3]: JavaScript virtual machines like V8 (used in Google Chrome, Node.js) or SpiderMonkey (used in Mozilla Firefox) implement (a subset of) the *Chrome DevTools Protocol*. External debugging utilities use CDP to connect and debug JavaScript programs. vscode ships with *js-debug*, a control-flow oriented JavaScript debugger, relying on CDP.

[^4]: We contributed the possibility for CDP connection-reuse to js-debug as part of our work on the RxJS RP debugging extension. https://github.com/microsoft/vscode-js-debug/pull/964

# Usability Validation {#sec:discussion}

Making use of a User Centered Design (UCD) approach, we implemented our extension in three iterations: After sketching a rough (i) proof of concept (POC), we performed a cognitive walkthrough to validate our idea of replacing manual print statements with operator log points. The resulting data helped us to build a (ii) prototype of the extension. We conducted a moderated remote usability test with three subjects, which allowed us to uncover blind spots in the UX concept of the prototype as well as finding bugs early in the development process. We used the results of these sessions for further refinement and finalized the (iii) first minor version of the RxJS RP debugger, which we released to the Visual Studio Marketplace in May 2021.

For both the cognitive walkthrough and the remote usability test, we reused the objects for testing created by Alabor et al. [@Alabor_Stolze_2020] for their observational study^[https://github.com/swissmanu/mse-pa1-experiment]. Since their study subjects reportedly used manual print statements to debug  those, we were able to minimize the introduction of unwanted bias by creating new examples for our usability inspections.

## Cognitive Walkthrough

The first iteration on building an RxJS debugger resulted in a POC demonstrating the basic concept of operator log points as a vscode extension.

At this early stage of development, we were looking for an informal, expert-driven usability inspection method [@Nielsen_1994], which we found in the cognitive walkthrough [@Wharton_Rieman_Clayton_Polson_1994]. After we prepared the persona of *Frank Flow*, the profile of a typical user of the RP debugger, we designed the action sequence for the walkthrough (Table [2](#tbl:cognitive-walkthrough)) based on the debugging process by Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] and Franks potential workflow to debug the *Problem 1* web application by Alabor et al.

```{.include}
content/tables/steps-cognitive-walkthrough.tex
```

We successfully identify six major usability issues during the later steps of the walkthrough, as summarized in Table [3](#tbl:cognitive-walkthrough-issues). The full walkthrough report, including the persona description of Frank Flow, is available in **XXX Where do we make this available? Appendix? Additional document? ...?**.

```{.include}
content/tables/issues-cognitive-walkthrough.tex
```



## Moderated Remote Usability Test

After the initial validation using the cognitive walkthrough by ourselves, we were ready to show the refined prototype to actual users.

### Study Design

The optimal number of participants for a think aloud test are five subjects [@Nielsen_Participants_1994]. However, we decided that three software engineers were a sufficient number of participants since we were looking for a basic indication if our debugger improved anything at all rather than the thoroughness of a full usability test. We recruited the subjects for the usability test via Twitter. The participants were required to have at least worked with RxJS during the past year and use vscode as their main IDE. We sent out a PDF containing a short briefing and the feature description of the prototype a week before the actual test session. Along with the main goal, performing the usability test for a novel RxJS debugger, the briefing emphasized on the importance of "think aloud" [@Boren_Ramey_2000; @Norgaard_Hornbaek_2006], the practice of verbalizing thoughts constantly without reasoning about them. Further, we informed the subjects about the minimal software requirements (Zoom, Node.js, npm/Yarn and vscode) for the remote usability test.

### Study Execution

At the start of a test session, we provided each participant with a ZIP file^[https://github.com/swissmanu/mse-pa2-usability-test] containing the *Problem 2* web application by Alabor et al. and the packaged version of the debugger extension prototype^[https://github.com/swissmanu/mse-pa2-spike-vscode] for vscode. While the subject prepared their development environment, we started the video, screen, and audio recording with their consent. Further, we gave a short introduction to the code base they just received.

Once the participants had everything set up, they worked for 25 minutes finding and solving any bugs in the provided web application. We took care to repeatedly remind a participant not vocalizing their thoughts.

### Study Evaluation

One participant was not able to get the prototype extension up and running on their system, which means we had only two valid data sets for further evaluation after study execution. We categorized the observed usability issues by debugging process phase (i.e. gather context, instrument hypothesis, and test hypothesis) and task (e.g. "Setup Environment", "Manage Log Points", or "Interpret Log"). From a total of 10 issues, we observed four being a problem for both remaining study subjects. These issues are summarized in Table [4](#tbl:issues-usability-test) and we prioritized them as "major". The full report with all usability issues is available in **XXX Where do we make this available? Appendix? Additional document? ...?**

```{.include}
content/tables/issues-usability-test.tex
```

The final extension we presented in Section [4](#sec:implementation) would not have been possible without the valuable insight we gained during the remote usability test. So are e.g. the display of life cycle events within the source code editor instead of in a separate window pane or indicating suggested operator log points with an icon direct measures in order to mitigate major issues observed during the test sessions.


# Threats to Validity {#sec:threats_to_validity}

The results of the usability test are subject to the following threats and limitations:

## Internal Validity

The usability test was performed in an uncontrolled, remote environment and all participants used their own computers and software installations. The down side of this setup was the early failure of one subject, which could not get the prototype extension running on their system. Even though this could have been prevented in a controlled lab, we deem the data we were able to collect to be of the same quality as when it would have been collected in a lab [@Andreasen_Nielsen_Schroder_Stage_2007].

## External Validity

Due to the circumstance that one study participant could not set up the prototype extension, we ended up having only two valid data sets after the the remote usability tests. According to Nielsen et al. [@Nielsen_Landauer_1993], we discovered around 50% of all usability issues present this way. We observed two participants sharing four of 10 issues, thus we are confident having found the most critical ones nonetheless.

## Construct Validity

We consider asking the subjects to "think aloud" during the remote usability test to create an unfamiliar environment; software engineers are usually not used to "speak to themselves" when working on a problem. Even though a participant might not vocalize their thoughts at all time, the screen and video recordings of the session mitigates the risk of missing important data. Careful moderation during the session [@Boren_Ramey_2000] helped further to remind a silent participant to tell us about their thoughts without risking to influence the result.

# Future Work {#sec:future_work}

There are several ways how future work might contribute to the efforts presented in this paper. For a better overview, we grouped them into two categories: *Research* and *Features*.

## Research

We validated the demonstrated RxJS RP debugger mainly for its UX  and usability with two different inspection methods during development. So far, we did not put any work into further, empirical validation of the novel debugger. We see three possibilities how this might be approached: (i) There is a steep learning curve for software engineers starting with RxJS [@Alabor_Stolze_2020]. It might be interesting to see, if the tools provided by the RP debugger ease the first steps with RxJS for those engineers. (ii) A quantitative study, comparing the effectiveness of control-flow and the new data-flow oriented debugger would further justify the efforts invested in the presented debugger and lead the way for further development. Lastly, (iii) a new observational study with experienced RxJS engineers to validate pervious findings [@Alabor_Stolze_2020] would prove that "readiness-to-hand" is indeed of uttermost importance when it comes to effective debugging utilities.

As of writing this paper, the latest version v0.1.2 of *RxJS Debugging for vscode* is the product of two usability inspections. More usability testing of this version will further improve the overall UX, since we have no confirmation on the presence nor absence of newly introduced usability issues.

## Features

We designed the project governance around *RxJS Debugging for vscode* as an open source project. We present three highliths from the feature back log^[[https://github.com/swissmanu/rxjs-debugging-for-vscode/issues](https://github.com/swissmanu/rxjs-debugging-for-vscode/issues?q=is%3Aopen+is%3Aissue+label%3Afeature%2Cimprovement)] which is publicly available on Github.

### Visualizer Component^[[https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/50](https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/50)]

*RxFiddle* by Banken et al. [@Banken_Meijer_Gousios_2018] proposed visualization functionalities for data-flow graphs declared using RxJS observables. Adding a component representing complex graphs visually will be a helpful addition in order to comprehend such structures better.

### Record/Replay^[[https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/51](https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/51)]

Recording telemetry data of a running RP program and replaying that data independently [@OCallahan_Jones_Froyd_Huey_Noll_Partush_2017; @Perez_Nilsson_2017] can help to simplify testing a debugging hypothesis in complex systems. Recorded data might be used to test a modified system without re-executing the complete RP program further.

### Time Travel Debugging^[[https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/62](https://github.com/swissmanu/rxjs-debugging-for-vscode/issues/62)]

Once there is a way to record, store and replay telemetry data, omniscient[@Pothier_Tanter_2009], or "time travel" debugging is a viable next step. Software engineers can manually step through recorded data and observe how individual parts of the system react on the stimuli. Contrary regular control-flow oriented debuggers, time travel debuggers can step forward as well as backward in time, since they do not rely on an actual running program.


# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

