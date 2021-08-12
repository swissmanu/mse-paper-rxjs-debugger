# Introduction

When software engineers look at the source code of an existing application, they want to learn about how the program was implemented technically. They might do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g. during onboarding of a new team member) or, more often, because someone reported an unexpected behavior of the application (e.g. the program crashed). This kind of work is commonly known as "debugging" [@IEEE_Glossary]. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three concrete steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. With the goal to prove this hypothesis, the engineer (ii) instruments the program using appropriate techniques. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

![TODO: Replace with proper graphic; Orient steps clockwise; Iterative Debugging Process after Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]: Gather context to formalize hypothesis, instrument hypothesis producing a modified system, and testing hypothesis resulting in a new iteration or a successfully proved hypothesis.](./content/debugging-process.png)

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

This debugging technique is often time consuming and cumbersome: The more print statements are added, the more log entries get generated, which in turn are harder to analyze and interpret. The print statements might further reside in the source code after the engineer finished with their debugging activities. This results in production artifacts containing irrelevant code or even newly introduced bugs if the engineers miss to clean up their instrumented code carefully.

# Related Work {#sec:background}

Salvaneschi et al. [@Salvaneschi_Mezini_2016] identified the divergence between expected and actual behavior of a control-flow oriented debugger as one of their key motivations for RP debugging: The stack-based runtime model of control-flow oriented debuggers does not match the software engineers data-flow oriented mental model of the program they are debugging. This is because the debugger has a "lack of abstractions"; it cannot interpret high-level RP abstractions and works on the low-level implementations of the regarding RP runtime environment instead. The group proposed the first specialized RP debugging solution for RP programs implemented with REScala [@Salvaneschi_Hintz_Mezini_2014], a RP runtime for the Scala^[https://scala-lang.org/] programming language. Integrated in the Eclipse IDE, the utilities provide a wide range of RP debugging functionalities like the visualization of data-flow graphs and the information that traverses through them. Reactive breakpoints allow further to interrupt program execution once a graph node re-evalutes its value.

Since then, RP gained more traction across various fields of software engineering. With a shared vision on how to surface RP abstractions on API level, *ReactiveX*^[http://reactivex.io/] consolidated numerous projects under one open source organization. Together, its members provide RP runtime environments for many of todays mainstream programming languages like Java, C#, or Swift. For the development of JavaScript-based applications, software engineers can rely on RxJS^[https://rxjs.dev]. One of the more popular adopters of this library is Google Angular^[https://angular.io/], a framework to develop web frontend applications, where it is used to model asynchronous operations like fetching data.

Two years after Salvaneschi et al. proposed RP Debugging, Banken et al. [@Banken_Meijer_Gousios_2018] showed in their paper that debugging RxJS-based RP programs is not that different from REScala-based ones. They were able to categorize the debugging motivations of their study participants into four main, overarching themes. These can be put into direct correlation with the debugging issues identified by Salvaneschi et al. earlier as we show in Table [1](#tbl:salvaneschi-vs-banken).

```{.include}
content/table-salvaneschi-vs-banken.tex
```

The authors further provided a debugger in form of an isolated visualizer sandbox: *RxFiddle*. The browser-based application executes an RxJS program and visualize its runtime behavior in two dimensions: A central (i) data-flow graph shows which elements in the graph interact with each other and a dynamic (ii) marble diagram[^1] represents the values which were processed by the graph over time.

[^1]: Marble diagrams are a visualization technique used throughout the ReactiveX community to describe the behavior of a node in a data-flow graph graphically. A marble represents a value emitted by such a graph node. Marbles are arranged on a thread from left to right, indicating the point in time when their value was emitted. See https://rxmarbles.com/ for more examples.

Both Banken et al. and Salvaneschi et al. suggested technical architectures for RP debugging systems. Both suggestions can be summarized as distributed systems consisting of two main components: The (i) instrumented RP runtime environment is augmented to produce debugging-relevant events (e.g. value emitted or graph node created). These events get processed by the actual (ii) debugger which provides a UI to inspect the RP programs state eventually.

Another two years after Banken et al. published their work, Alabor et al. [@Alabor_Stolze_2020] examined the state of RxJS RP debugging. According to their research, software engineers still struggle to use appropriate tools to debug RxJS programs. The observational study the authors conducted produced the key finding of their work: Even though their subjects stated to know about suitable RP debugging utilities, none of them used such tools during the study. Alabor et al. credit this circumstance to the fact that their participants IDEs did not provide such suitable RP debugging utilities right at hand.

Alabor et al. conclude that knowing about the correct RP debugging utility (e.g. *RxFiddle*) is not enough. The barrier to use such utilities must be minimized; i.e. in order to live up to their full potential, RP debugging utilities must be fully integrated into the IDE so using them is ideally only an engineers keypress away.

# Readiness-to-hand: An RxJS RP Debugger {#sec:implementation}

We translated these findings into the central principle for the design of our RP debugger for RxJS: *Readiness-to-hand*. Software engineers should always have the proper debugging tool ready, no matter what kind of program they are currently confronted with. Further, this tool should integrate with the engineers workflow seamlessly.

## Features

We made manual print statements for debugging RxJS RP programs obsolete by providing a better alternative with *RxJS Debugging for vscode*. For this, we implemented *Operator Log Points*, a similar tool to *probes* as proposed by McDirmid [@McDirmid_2013] for live programming environments. The extension achieves this by continuously parsing of the source code in the current editor. The resulting AST is evaluated in order to detect operators passed to the *pipe* function of an observable[^2]. For every operator detected, the extension suggests a log point by displaying a diamond icon. A suggested log point can be enabled by hovering the mouse pointer over its icon and selecting the *Add Operator Log Point* action (see Figure [3](#fig:operator-log-points)). With this, engineers have tne debugging tool right at hand.

[^2]: An RxJS *Observable* is an abstraction of a reactive source. Once a consumer *subscribes* the source, the source pushes/*emits* values, *completes* (e.g. when a network request has completed), fails with an *error*, or may get *unsubscribed* from the consumer. These are the five main life cycle events engineers are interested in when debugging an observable. An operators is a node in the materialized data-flow graph. An operator transforms emitted values or composes multiple observables.

Once the software engineer starts the RP program with vscodes built-in JavaScript debugger, our extension displays life cycle events for all enabled log points inline with the source code which produced the event. Engineers are free to enable or disable additional log points during the debugging session.

![*RxJS Debugging for vscode* used to debug code from Listing [2](#lst:rp): A diamond icon indicates operator log points: Specifically, a grey outline represents a suggested log point (Line 7), a filled, red diamond an enabled log point (Line 8). Life cycle event logs are shown at the end of the respective line in the source code editor (Line 8, "Unsubscribe"). Log points are managed by hovering a log point icon and selecting the appropriate action.](./content/operator-log-points.png)

## Architecture

The technical architecture of *RxJS Debugging for vscode* is a refined version of the system proposed by Banken et al. [@Banken_Meijer_Gousios_2018] and shares its fundamental components as shown in Figure [4](#fig:architecture): The *Telemetry* component runs in the same process as the debugged RP program augmenting it. Telemetry gathers and relays life cycle events to the debuggers *UI* component which runs as an extension in the vscode process.

![TODO do it nice & improve figure caption; The *Telemetry* component instruments the RP program (right). The *UI* component runs as an extension within vscodes process. The two components communicate with each other by piggybacking messages on the CDP communication channel, which is established by the generic vscode JavaScript debugger.](./content/architecture.png)

Contrary to *RxFiddle*, our implementation uses a different way to connect these two components. Where the solution by Banken et al. uses WebSockets to exchange messages, we leverage on the CDP[^3] connection, established by the generic JavaScript debugger, instead[^4]. We decided for this approach because it gives us two benefits out of the box: (i) UX-wise, the software engineer does not to decide "how" they want to debug their program (i.e. traditionally control-flow oriented or RP, data-flow oriented). They start debugging using familiar commands and RP specific debugging capabilities are provided once available without additional effort. (ii) Technically, we do not need to care for "where" the RP program the user wants to debug is running (e.g. locally in a browser or in a Node.js process on a remote computer) since this is already taken care for by the generic JavaScript debugger. The result is a robust, less complex system since we do not need to maintain an additional side channel for RP debugging communication.

[^3]: JavaScript virtual machines like V8 (used in Google Chrome, Node.js) or SpiderMonkey (used in Mozilla Firefox) implement (a subset of) the *Chrome DevTools Protocol*. External debugging utilities use CDP to connect and debug JavaScript programs. vscode ships with *js-debug*, a control-flow oriented JavaScript debugger, relying on CDP.

[^4]: We contributed the ability to reuse a CDP connection from the generic JavaScript debugger as part of our work https://github.com/microsoft/vscode-js-debug/pull/964

# Usability Validation {#sec:discussion}

Making use of a User Centered Design (UCD) approach, we implemented our extension in three iterations: After sketching a rough (i) proof of concept, we performed a cognitive walkthrough to validate our idea of replacing manual print statements with operator log points. The resulting data helped us to build the first (ii) prototype of our extension. A moderated remote usability test helped us uncovering blind spots in our UX concept as well as finding bugs early in the development process. The outcome finally allowed us to implement the (iii) first minor release, which we released to the Visual Studio Marketplace.

Alabor et al. [@Alabor_Stolze_2020] used two, small web applications^[https://github.com/swissmanu/mse-pa1-experiment] in their observational study. Because their participants reportedly used manual print statements to debug these applications, we decided to reuse *Problem 2*, the more complex application, of the authors for our usability inspections. Using an already validated object for testing helped us to prevent  introducing unwanted bias.

## Cognitive Walkthrough

- Cognitive Walkthrough
	- [@Wharton_Rieman_Clayton_Polson_1994]
	- [@Nielsen_1994]
	- https://github.com/swissmanu/mse-paper-pa2
- Use Case: Alabor et al. [@Alabor_Stolze_2020]

## Moderated Remote Usability Test

- Moderated Remote Usability Test
	- Use Case: again: Alabor et al. [@Alabor_Stolze_2020]
  - Systematic: Synchronous Remote Usability Evaluation
    - [@Andreasen_Nielsen_Schroder_Stage_2007]
  - Think aloud:
    - [@Boren_Ramey_2000]
    - [@Norgaard_Hornbaek_2006]
	- 3 Participants ... cite why this is enough regarding Nielsen
	- Outcome

# Threats to Validity {#sec:threats_to_validity}

- Usability study scope
- "only" based on [@Alabor_Stolze_2020]

## Internal Validity

## External Validity

## Construct Validity


# Future Work {#sec:future_work}

## Features

- Support for Browser-based Applications (Selling point: Angular)
- Visualization of data flows
- Omniscient/time travel debugging for data flows
- Record/replay of data sources for later simulation
	- [@Perez_Nilsson_2017]

## Research

- Verify if extension helps beginners to get started with RxJS
- Verify effectiveness of extension for professionals (re-execute previous observational study)
- More Usability Testing

# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

