# Introduction

When software engineers look at the source code of an existing application, they want to learn about how the program was implemented technically. They might do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g. during onboarding of a new team member) or, more often, because someone reported an unexpected behavior of the application (e.g. the program crashed). This kind of work is commonly known as "debugging" [@IEEE_Glossary]. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three concrete steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. They then (ii) instrument the program using appropriate techniques to prove their hypothesis. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

```{.include}
content/figures/debugging-process.tex
```

The most basic debugging technique for instrumentation and testing are manually added print statements to the source code: They generate execution logs when placed  across the programs code and allow the reconstruction of the programs runtime behavior. Once the number of generated log entries increases, the required amount of work to analyze the logs gets out of hand quickly. This is why specialized debugging utilities provide tools to interact with a program at runtime: After interrupting program execution with a breakpoint, they allow engineers to inspect stack frames, inspect and modify variables, step through successive source code statements, or resume program execution eventually. These utilities work best with imperative, or control-flow oriented programming languages since they interact with the debugged program on a statement and stack frame level.

Modern IDEs enable software engineers to debug programs, no matter what programming language they are implemented with, using one, generalized user interface (UI). The result is a unified user experience (UX) where the supposed correct debugger is only a click away.

By integrating control-flow oriented debugging utilities into their workflows, software engineers face a new problem when working with reactive programming (RP) though. Alabor et al. [@Alabor_Stolze_2020] highlighted that participants of their study intuitively expected their debuggers step controls to work on the RP data-flow graph and were surprised that they did not. This discrepancy between expected and actual behavior of the debugger let engineers fall back to adding manual print statements.

This debugging technique is time consuming and cumbersome: The more print statements are added, the more log entries get generated, which in turn are harder to analyze and interpret. The print statements might further reside in the source code after the engineer finished with their debugging activities. This results in production artifacts containing irrelevant code or even newly introduced bugs if the engineers miss to clean up their instrumented code carefully.

The observation of debugging RP programs with the wrong debugging utilities is not new: Salvaneschi et al. described the shortcoming of traditional debuggers when confronted with RP in their paper and coined the concept of *RP Debugging* [@Salvaneschi_Mezini_2016]. Later, Banken et al. [@Banken_Meijer_Gousios_2018] proposed a possible solution for debugging RxJS RP programs using an external visualizer sandbox. However, software engineers still do not have the right tools at hand today when needing them most, as Alabor et al. stated.

Within this paper, we are going to present two concrete contributions to the field of RxJS RP debugging:

1. *RxJS Debugging for Visual Studio Code* is an extension for Microsoft Visual Studio Code^[[https://code.visualstudio.com](https://code.visualstudio.com)] (vscode) and provides operator log points to debug RxJS-based programs. It integrates with UX patterns conforming to the IDE and requires no extra effort to debug an RP program.

2. A refined architecture for RxJS RP debuggers reusing a preexisting *Chrome DevTools Protocol*[^3] (CDP) connection for message-based communication between the debuggers individual components.

[^3]: JavaScript virtual machines like V8 (Google Chrome, Node.js) or SpiderMonkey (Mozilla Firefox) implement (a subset of) the *Chrome DevTools Protocol*. External debugging utilities use CDP to connect and debug JavaScript programs. vscode ships with *js-debug*, a control-flow oriented JavaScript debugger, relying on CDP. [https://chromedevtools.github.io/devtools-protocol/](https://chromedevtools.github.io/devtools-protocol/)


***TODO Rewrite** Before we do a deep-dive on the extensions functionality in Section [4](#sec:implementation), we will give an example for the main challenge of RP debugging in Section [2](#sec:challenge). We discuss related work in Section [3](#sec:background). Before we come to our conclusion in Section [8](#sec:conclusion), we will consider potential threats to validity in Section [6](#sec:threats_to_validity) and give an overview on potential follow-up topics, research-wise as well as practical, in Section [7](#sec:future_work).*

# RP Debugging: The Hard Way {#sec:challenge}

One of the main characteristics of RP is the paradigm shift away from imperatively formulated, control-flow oriented code (see Listing [1](#lst:imperative)), over to declarative, data-flow focused source code [@Salvaneschi_Mezini_2016]. Instead of instructing the program how to do what, i.e. one step after another, we use RP abstractions to describe the transformation of a continuous flow of data.

```{caption="Basic example of imperative-style/control-flow oriented programming in TypeScript: Multiply integers between 0 and 4 for every value that is smaller than 4 and call reportValue with the result." label=imperative .Typescript}
import reportValue from './reporter';

for (let i = 0; i < 5; i++) {
  if (i < 4) {
    reportValue(i * 2);
  }
}
```

RxJS abstracts reactive sources with *Observables*. Once a sink, called consumer *subscribes* the source, the source starts to *emit* values, *completes* (e.g. when a network request has completed), fails with an *error*, or may get *unsubscribed* from the consumer. These five life cycle events, propagated through the data-flow graph, can be transformed using *Operators*. An operator might modify values, compose other observables, or change how life cycle events get forwarded. Listing [2](#lst:rp) shows an example of a source observable, two operators and one consumer.

```{caption="Basic RP example implemented with RxJS in TypeScript: Generate a data-flow of integers from 0 to 4, skip values equal or larger then 4, multiply these values by 2 and call reportValue with each resulting value." label=rp .Typescript}
import reportValue from './reporter';
import { of } from 'rxjs';
import { filter, map } from 'rxjs/operators';

of(0, 1, 2, 3, 4).pipe( // Flow of integers 0..4
  filter(i => i < 4),   // Omit 4
  map(i => i * 2),      // Multiply with 2
).subscribe(reportValue)
```

Traditional debuggers reach their limitations when facing data-flow oriented code: While we can navigate through the successive iterations of the *for* loop in Listing [1](#lst:imperative) using their step controls, this is not possible for the transformations described in Listing [2](#lst:rp): Assuming we set a breakpoint within the lambda function passed to *filter* on Line 6, stepping over to the next statement will not lead to the lambda of *map* on Line 7 as one might expect. Instead, the debugger will continue in the internal implementations of *filter*, which is part of the RxJS RP runtime environment. With a deeper understanding of what the difference between control- and data-flow oriented programing is, this might look plausible. Alabor et al. showed however that software engineers expect a different behavior from the debugging tools they have at hand [@Alabor_Stolze_2020]. As a direct consequence, engineers fall back to the archaic debugging technique of adding manual print statements, as exemplified in Listing [3](#lst:rp-print).

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


# Related Work {#sec:background}

Salvaneschi et al. [@Salvaneschi_Mezini_2016] identified the divergence between expected and actual behavior of a control-flow oriented debugger as one of their key motivations for RP debugging: The stack-based runtime model of control-flow oriented debuggers does not match the software engineers data-flow oriented mental model of the program they are debugging. This is because the debugger has a "lack of abstractions"; it cannot interpret high-level RP abstractions and works on the low-level implementations of the regarding RP runtime environment instead. The group proposed the first specialized RP debugging solution for RP programs implemented with REScala [@Salvaneschi_Hintz_Mezini_2014], a RP runtime for the Scala programming language. Integrated in the Eclipse IDE, the utilities provide a wide range of RP debugging functionalities like the visualization of data-flow graphs and the information that traverses through them. Reactive breakpoints allow further to interrupt program execution once a graph node re-evalutes its value.

Since then, RP gained more traction across various fields of software engineering. With a shared vision on how to surface RP abstractions on API level, *ReactiveX*^[[http://reactivex.io/](http://reactivex.io/)] consolidated numerous projects under one open source organization. Together, its members provide RP runtime environments for many of todays mainstream programming languages like Java, C#, or Swift. For the development of JavaScript-based applications, software engineers can rely on RxJS^[[https://rxjs.dev](https://rxjs.dev)]. One of the more popular adopters of this library is Google Angular, a framework to develop web frontend applications, where it is used to model asynchronous operations like fetching data.

Two years after Salvaneschi et al. proposed RP Debugging, Banken et al. [@Banken_Meijer_Gousios_2018] showed in their paper that debugging RxJS-based RP programs is not that different from REScala-based ones. They were able to categorize the debugging motivations of their study participants into four main, overarching themes. These can be put into direct correlation with the debugging issues identified by Salvaneschi et al. earlier as we show in Table [1](#tbl:salvaneschi-vs-banken).

```{.include}
content/tables/table-salvaneschi-vs-banken.tex
```

The authors further provided a debugger in form of an isolated visualizer sandbox: *RxFiddle*. The browser-based application executes an RxJS program and visualizes its runtime behavior in two dimensions: A central (i) data-flow graph shows which elements in the graph interact with each other and a dynamic (ii) marble diagram[^1] represents the values which were processed by the graph over time.

[^1]: Marble diagrams are a visualization technique used throughout the ReactiveX community to describe the behavior of a node in a data-flow graph graphically. A marble represents a value emitted by a graph node. Marbles are arranged on a thread from left to right, indicating the point in time when their value was emitted. See [https://rxmarbles.com/](https://rxmarbles.com/) for more examples.

Both Banken et al. and Salvaneschi et al. suggested technical architectures for RP debugging systems. Both suggestions can be summarized as distributed systems consisting of two main components: The (i) instrumented RP runtime environment is augmented to produce debugging-relevant events (e.g. value emitted or graph node created). These events get processed by the actual (ii) debugger which provides a UI to inspect the RP programs state eventually.

Another two years after Banken et al. published their work, Alabor et al. [@Alabor_Stolze_2020] examined the state of RxJS RP debugging. According to their research, software engineers struggle to use appropriate tools to debug RxJS programs. They performed an observational study and found instances of engineers which stated to know about RP specific debugging tools but refrained from using them during the experiment. The authors credited this circumstance to the fact that the IDEs of their participants did not provide suitable RP debugging utilities right at hand.

Alabor et al. conclude that knowing about the correct RP debugging utility (e.g. *RxFiddle*) is not enough. The barrier to use such utilities must be minimized; i.e. in order to live up to their full potential, RP debugging utilities must be fully integrated into the IDE so using them is ideally only an engineers key press away and adheres to accustomed, known UX patterns further.


# Readiness-to-hand: An RxJS RP Debugger {#sec:implementation}

We translated these findings into the central principle for the design of our RP debugger for RxJS: *Readiness-to-hand*. Software engineers should always have the proper debugging tool ready, no matter what type of program they are currently confronted with. Further, this tool should integrate with the engineers workflow seamlessly.

## Features

We made manual print statements for debugging RxJS RP programs obsolete by providing a better alternative with *RxJS Debugging for vscode*. For this, we implemented *Operator Log Points*, a similar tool to *probes* as proposed by McDirmid [@McDirmid_2013] for live programming environments. The extension suggests a log point for every operator function detected. The engineer may enable such a log point by hovering the mouse pointer over its icon and selecting the *Add Operator Log Point* action (see Figure [2](#fig:operator-log-points)). Once the software engineer starts the RP program with vscodes built-in JavaScript debugger, the extension displays life cycle events for all enabled log points inline with the source code which produced the event. Engineers are free to enable or disable additional log points during the debugging session.

Log point suggestions are generated by continuously parsing the source code of the current editor. The extension evaluates the resulting AST in order to detect operators passed to the *pipe* function of an observable.

![*RxJS Debugging for vscode* used to debug code from Listing [2](#lst:rp). A diamond icon indicates operator log points: A grey outline represents a suggested log point (Line 7), a filled, red diamond an enabled log point (Line 8). Life cycle event logs are shown at the end of the respective line in the source code editor (Line 8, "Unsubscribe"). Log points are managed by hovering a log point icon and selecting the appropriate action.](./content/figures/operator-log-points.png)

The result is a strikingly simple, yet effective way to explore and trace the runtime behavior of RxJS observables. Hence, this simplicity is possible because of a coordinated, distributed system behind the curtains.

## Architecture

The technical architecture of *RxJS Debugging for vscode* is a refined version of the system proposed by Banken et al. [@Banken_Meijer_Gousios_2018] and shares its fundamental components as shown in Figure [4](#fig:architecture): The *Telemetry* component runs in the same process as the debugged RP program augmenting it. Telemetry gathers and relays life cycle events to the debugger extension component running in the vscode process.

```{.include}
content/figures/architecture.tex
```

Contrary to *RxFiddle*, our implementation uses a different way to connect these two components. Where the solution by Banken et al. uses WebSockets to exchange relevant data, we leverage on the CDP connection, established by the generic JavaScript debugger, instead[^4]. The result is a robust, less complex system because we do not need to maintain any additional side channel for RP debugging communication. This approach contributes to our solution two ways: (i) Technically, we do not need to care for "where" the RP program the user wants to debug is running (e.g. locally in a browser or in a Node.js process on a remote computer). This is taken care for by the generic JavaScript debugger already. (ii) UX-wise, the software engineer does need not to decide "how" they want to debug their program (i.e. traditionally control-flow oriented or RP, data-flow oriented). They start debugging using familiar commands and RP specific debugging capabilities are provided once available.

[^4]: We contributed the possibility for CDP connection-reuse to js-debug as part of our work on the RxJS RP debugging extension: **WARNING: This link might reveal the authors identity** [https://github.com/microsoft/vscode-js-debug/pull/964](https://github.com/microsoft/vscode-js-debug/pull/964)

# Usability Validation {#sec:discussion}

For conceptualizing and implementing our debugging utility, we followed a User Centered Design (UCD) approach in three iterations: After sketching a rough (i) proof of concept (POC), we performed a cognitive walkthrough to validate our idea of replacing manual print statements with operator log points. The resulting data helped us to build a (ii) prototype of the extension. We used this prototype to conduct a moderated remote usability test with three subjects. This allowed us to uncover pitfalls in the UX concept as well as finding bugs early in the development process. We used the results of these sessions for further refinement and finalized the (iii) first minor version of the RxJS RP debugger, which we released to the Visual Studio Marketplace in May 2021.

For both the cognitive walkthrough and the remote usability test, we reused the objects for testing created by Alabor et al. [@Alabor_Stolze_2020] for their observational study.

## Cognitive Walkthrough

We concluded the first iteration of our development process with a POC demonstrating the basic concept of operator log points for vscode.

At this early stage of development, we were looking for an informal, expert-driven usability inspection method [@Nielsen_1994], which we found in the cognitive walkthrough [@Wharton_Rieman_Clayton_Polson_1994]. After we prepared the persona of *Frank Flow*, the profile of a typical user of the RP debugger, we designed the action sequence for the walkthrough (Table [2](#tbl:cognitive-walkthrough)) based on the debugging process by Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] and Franks potential workflow to debug the *Problem 1* web application by Alabor et al.

```{.include}
content/tables/steps-cognitive-walkthrough.tex
```

We successfully identify six major usability issues during the later steps of the walkthrough, as summarized in Table [3](#tbl:cognitive-walkthrough-issues). The full walkthrough report, including the persona description of Frank Flow, is available on Github^[**WARNING: This link might reveal the authors identity** [PROVIDE REPORT](https://github.com/)].

```{.include}
content/tables/issues-cognitive-walkthrough.tex
```



## Moderated Remote Usability Test

After the initial validation using the cognitive walkthrough by ourselves, we were ready to test the refined prototype to real users.

### Study Design

"Think aloud" tests for systems with a high functionality saturation benefit from at least five test subjects or more [@Nielsen_Participants_1994]. The feature spectrum of the RP debugger prototype was small, which is why we decided to work with a subject population of three individuals. All participants, recruited via Twitter, were required to have at least worked with RxJS during the past year and use vscode as their main IDE. We sent out a PDF containing a short briefing and the description of the prototype a week before the actual test session. The briefing contained information about software requirements (Zoom, Node.js, npm/Yarn and vscode) as well as details on what the subjects might encounter during their test session. Here, we emphasized on the importance of "think aloud" [@Boren_Ramey_2000; @Norgaard_Hornbaek_2006], the practice of continuously verbalizing thoughts without reasoning about them.

### Study Execution

At the start of a test session, we provided each participant with a ZIP file^[**WARNING: This link might reveal the authors identity** [https://github.com/swissmanu/mse-pa2-usability-test](https://github.com/swissmanu/mse-pa2-usability-test)] containing the *Problem 2* web application by Alabor et al. and the packaged version of the debugger extension prototype^[**WARNING: This link might reveal the authors identity** [https://github.com/swissmanu/mse-pa2-spike-vscode](https://github.com/swissmanu/mse-pa2-spike-vscode)] for vscode. While the subject prepared their development environment, we started the video, screen, and audio recording with their consent. Also, we gave a short introduction to the code base they just received.

Once the participants had everything set up, they worked for 25 minutes resolving any bugs in the provided web application.

### Study Evaluation

One participant was not able to get the prototype extension up and running on their system, which means we had only two valid data sets for further evaluation after study execution. We categorized the observed usability issues by debugging process phase (i.e. gather context, instrument hypothesis, and test hypothesis) and task (e.g. "Setup Environment", "Manage Log Points", or "Interpret Log"). From a total of 10 issues, we observed four being a problem for both remaining study subjects, thus we prioritized them as "major". The full usability issue report is available on Github^[**WARNING: This link might reveal the authors identity** [PROVIDE REPORT](https://github.com/)]. Table [4](#tbl:issues-usability-test) presents the four major issues.

```{.include}
content/tables/issues-usability-test.tex
```

## Application of Results

The results from the cognitive walkthrough as well as the usability tests were essential input on the way of developing the RxJS RP debugger presented in Section [4](#sec:implementation). E.g., both the POC and the prototype had an extra view for displaying life cycle events. We classified this concept during the walkthrough as prone to confuse the user. This suspicion was confirmed later during the usability test with real subjects. Because of this, we replaced the detached view with an inline display of life cycle events, directly in the source code editor. The way, how the extension surfaces operator log point suggestions, is another example of an improvement implemented based on the validation results: Subjects were not aware that suggested log points are available via the code action menu, even though this is an established UX pattern in vscode. We removed the suggestions from this menu and introduced the diamond-shaped indicator icon.


# Threats to Validity {#sec:threats_to_validity}

The results of the usability test are subject to the following threats and limitations:

## Internal Validity

The usability test was performed in an uncontrolled, remote environment and all participants used their own computers and software installations. The down side of this was the early failure of one subject, which could not get the prototype extension running on their system, hence not participate in the test at all. Even though this situation could have been prevented in a controlled lab environment, we consciously decided for a remote environemnt because of its simpler setup and accepted the risk of reduced validity and reproducibility.

## External Validity

Due to the circumstance, that one study participant could not set up the prototype extension, we ended up having only two valid data sets after the the remote usability test. Two test subjects should have allowed us to find around 50% of all usability issues present [@Nielsen_Landauer_1993]. Because the two remaining subjects share four of 10 issues, we are confident, that we could identify the most important usability problems nonetheless.

## Construct Validity

We carefully moderated the test session once a test subject fell silent for more then 10 seconds and missed to "think aloud". Even though the participants told us, that "speaking to themselves" creates an unfamiliar environment for them (software engineers are usually not used to "speak to themselves" when working on a problem), we expect the moderation techniques used [@Boren_Ramey_2000] to minimize any influences on the results.

# Future Work {#sec:future_work}

There are several ways how future work might contribute to the efforts presented in this paper. For a better overview, we grouped them into two categories: *Research* and *Features*.

## Research

As of writing this paper, *RxJS Debugging for vscode* is available in version v0.1.2 allowing to debug RxJS applications running in Node.js. Once v1.0.0^[**WARNING: This link might reveal the authors identity** [https://github.com/swissmanu/rxjs-debugging-for-vscode/milestone/2](https://github.com/swissmanu/rxjs-debugging-for-vscode/milestone/2)] introduces support for debugging such programs running in internet browsers, we see the necessity for two new empirical studies: (i) An observational study to answer the question, if "readiness-to-hand" is indeed of uttermost importance when it comes to effective RP debugging utilities [@Alabor_Stolze_2020]. Further, (ii) we propose to test the effectiveness of the presented RP debugger for RxJS compared to traditional debugging utilities like manual print statements and control-flow oriented debuggers.

Even though we validated the UX concepts of the new RxJS debugger twice during its development, more usability testing would potentially provide hints on how the UX could be improved further.

## Features

We designed *RxJS Debugging for vscode* to be an open source project. In the following, we present three highlights from its on Github publicly accessible feature back log^[**WARNING: This link might reveal the authors identity** [https://github.com/swissmanu/rxjs-debugging-for-vscode/issues](https://github.com/swissmanu/rxjs-debugging-for-vscode/issues?q=is%3Aopen+is%3Aissue+label%3Afeature%2Cimprovement)].

### Visualizer Component

*RxFiddle* by Banken et al. [@Banken_Meijer_Gousios_2018] proposed visualization functionalities for data-flow graphs described with RxJS observables. The debugging utilities we presented in this paper could benefit from the integration of such a visualizer. Having a graphical representation of an observable graph could help novice engineers understand RxJS concepts better; experienced engineers might benefit from a new angle on the composition of multiple observables when debugging such.

### Record and Replay

A software engineer can record telemetry data of a running RP program and replay that data independently as many times as they wish later [@OCallahan_Jones_Froyd_Huey_Noll_Partush_2017]. Such a function would allow two things: During debugging, the engineer can rerun a recorded failure scenario without depending on external systems like remote API's. Recorded data might be used for regression testing to verify that a modified program still works as expected [@Perez_Nilsson_2017] additionally.

### Time Travel Debugging

Once there is a way to record, store and replay telemetry data, omniscient [@Pothier_Tanter_2009], or "time travel" debugging is a possible next step. Software engineers can manually step through recorded data and observe how individual parts of the system react on the stimuli. Contrary regular control-flow oriented debuggers, time travel debuggers can not only step forward, but backward in time as well. This is because they do not rely on a currently running program.


# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

