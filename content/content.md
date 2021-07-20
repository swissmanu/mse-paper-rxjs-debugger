# Introduction

Software development consists of two parts: The first part is about creating novel applications, about the creative process [CITE] of building solutions to specific problems [CITE]. The other part is about understanding the behavior, source code and composition of existing programs [CITE]. All software engineer begin to develop the second skill once they start improving their programming abilities: Right from the point where they read their first "Hello World" code example, they start to build an intuition on how a computer might interpret and execute a given piece of source code. Once things get more involved, simply "thinking" through source code might not suffice anymore: A common technique to trace the runtime behavior of a program is the manual introduction of print statements to the source code. Multiple such statements, placed at key turning points of the program, generate extensive execution logs allowing to reconstruct the programs runtime behavior. Analyzing large amounts of logs is tedious work. Specialized debugging utilities provide more sophisticated tools to inspect programs at runtime: A breakpoint on a statement interrupts program execution. Once halted, engineers can inspect and modify variables in a stack frame, step through successive source code statements and eventually even resume normal program execution.

Debugging utilities integrated in todays IDEs have a strong focus on developong applications using an imperative programming paradigm: Breakpoints as well as stackframe and variable inspection are a good match for debugging imperatively formulated programs. These traditional debuggers face a new challenge when confronted with declarative programming paradigms, such as reactive programming (RP): Traditional debuggers cannot interpret the data-flow and runtime semantics of RP, and with that, fail to proof the debugging hypothesis [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formulated by the software engineer [@Salvaneschi_Mezini_2016_Inspector; @Alabor_Stolze_2020]. Salvaneschi et al. recognized this shortcoming of imperative debuggers and provided with *Reactive Inspector* [@Salvaneschi_Mezini_2016_Inspector] the first, fully IDE-integrated, RP-capable debugging solution for REScala [@Salvaneschi_Hintz_Mezini_2014], a RP runtime for the Scala programming language. Alabor et al. highlighted in their study [@Alabor_Stolze_2020] that other RP runtimes like RxJS^[https://rxjs.dev] did not benefit from the pioneering work by Salvaneschi et al. They could show that, due to the lack of fully integrated RP debugging solutions for RxJS, software engineers mostly fall back to the practice of using manual print statements when debugging RxJS-based programs.

We are going to present our solution to this problem in this paper: *RxJS Debugging for Visual Studio Code* is an extension for Microsoft Visual Studio Code^[https://code.visualstudio.com] and augments the IDE with RxJS-specific debugging capabilities. By doing so, it makes manual print statements a tool of the past.

Before we do a deep-dive on the extensions functionality in Section [4](#sec:implementation), we will give an example for the main challenge of reactive debugging in Section [2](#sec:challenge) and discuss the related work which lead to our solution in Section [3](#sec:related_work). Before we come to our conclusion in Section [8](#sec:conclusion), we will discuss potential Threats to Validity in Section [6](#sec:threats_to_validity) and give an overview on potential follow-up topics, research-wise as well as practical, in Section [7](#sec:future_work).

# Challenges of Reactive Debugging {#sec:challenge}

Understanding the fundamental process of debugging and how imperative program source code is debugged will help us to understand the struggles which come with reactive debugging.

## Formal Debugging Process

Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized debugging as three-step iterative process: (i) Engineers start with collecting information about the actual problem scenario: How can a specific situation be reproduced? What internal and external influences lead to that particular circumstance? The first step concludes with the formalization of a hypothesis intending to resolve the identified problem. Using debugging tools (e.g. breakpoints, print statements etc.), they then (ii) continue to instrument the program under inspection in order to proof their hypothesis. Once done, they (iii) test the instrumented program to proof the hypothesis. Should the hypothesis test outcome be negative, the engineer uses gained insight from the test and starts gathering context information again. This loop might be reexecuted until the hypothesis concludes in a positive result.

![TODO: Replace with proper graphic; Iterative Debugging Process after Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]: Gather context to formalize hypothesis, instrument hypothesis producing a modified system, and testing hypothesis resulting in a new iteration or a successfully proved hypothesis.](./content/debugging-process.png)

## Imperative Debugging

The commonly shipped debugging utilities shipped with modern IDEs are focused on working with imperative, control-flow oriented programs: In the instrumentation phase, breakpoints allow to interrupt program execution once reaching that particular statement in its source code. A stackframe inspector provides precise information on what code lead to the execution of the halted statement and the variable inspector shows values of variables valid in the current execution context. Variable and stackframe inspector are tightly integrated with each other: Navigating "back" in the stack will show the related variable values of the selected frame. The variable inspector further allows to modify values of specific variables at runtime. This is a powerful tool to instrument the debugging hypothesis as well.

Once the program is halted, step controls provide fine grained control on the successive program execution: Following statements can be executed one after another or regular program execution might be resumed.

## Reactive Debugging

One of the main characteristics of RP is the paradigm shift away from imperatively formulated, control-flow oriented code (see Listing [1](#lst:imperative)), over to declarative, data-flow focused source code [CITE]. Instead of instructing the program how to do what, one step after another, we use RP abstractions to describe the transformation of a potentially continuous flow of data as shown in Listing [2](#lst:rp).

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

Once switched from an imperative to declarative programming style, the imperative-focused debugger reaches its limitations quickly: Where it can be used to step through the successive iterations of the *for* loop in Listing [1](#lst:imperative) as expected, this is not possible for the transformations described in Listing [2](#lst:rp): Assuming there is a breakpoint placed within the lambda function passed to *filter* on Line 6, stepping over to the next statement will not lead to the lambda of *map* on Line 7 as one might expect. Instead, the debugger will continue in the internal implementations of *filter*, which is part of the RP runtime environment. This circumstance might becomes plausible once engineers get a deeper understanding of a particular RP implementation. Alabor et al. showed nonetheless that software engineers expect a different behavior from the debugging tools they know from earlier experiences [@Alabor_Stolze_2020]. As a direct consequence, most engineers fall back to the clumsy debugging technique of adding manual print statements like in Listing [3](#lst:rp-print) to instrument their debugging hypotheses, they conclude further.

```{#lst:rp-print caption="Manually added print statements on Lines 6, 8 and 10 to debug a data-flow implemented with RxJS in TypeScript." .Typescript}
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


# Related Work {#sec:related_work}

- Reactive Inspector [@Salvaneschi_Mezini_2016_Inspector]
- RxFiddle [@Banken_Meijer_Gousios_2018]
- Study by Alabor et al. [@Alabor_Stolze_2020]
  - Interviews
  - Observational Study

# Extension {#sec:implementation}

- New work:
	- Prototyp
	  - Describe how it relates to the debugging process [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]
	- UX Testing of Prototype. DONT CITE [@Alabor_2020], because not peer reviewed
	- The Result: An extension for Visual Studio Code, as described in the next section:
- Demonstrate/describe Extension
  - Log Points -> Relate with probes/traces [@McDirmid_2013]

# Discussion {#sec:discussion}

- *See if necessary as distinct section or if it can be integrated within previous section instead*

# Threats to Validity {#sec:threats_to_validity}

- Usability study scope
- "only" based on [@Alabor_Stolze_2020]

# Future Work {#sec:future_work}

- Features:
	- Support for Browser-based Applications (Selling point: Angular)
	- Visualization of data flows
	- Omniscient/time travel debugging for data flows
- Research:
	- Verify if extension helps beginners to get started with RxJS
	- Verify effectiveness of extension for professionals (re-execute previous observational study)
  - More Usability Testing
- Time travel debugging
  - Simulating predictable data sources
  - vs simulating concurrent systems

# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

