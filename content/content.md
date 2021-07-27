# Introduction

When software engineers look at the source code of an existing application, they want to learn about how the program was implemented technically. They might do this either because they want to get themselves acquainted with a new code base they never worked with before (e.g. during onboarding of a new team member) or, more often, because someone reported an unexpected behavior of the application (e.g. the program crashed). This kind of work is commonly known as "debugging" [@IEEE_Glossary] in the software engineering community. Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013] formalized an iterative process model (see Figure [1](#fig:debugging-process)) by dividing the broader task of debugging into three concrete steps: The engineer uses (i) gathered context information to build a hypothesis on what the problem at hand might be. With the goal to prove this hypothesis, the engineer (ii) instruments the program using appropriate techniques. Eventually, they (iii) test the instrumented program. If the outcome proves the hypothesis to be correct, the process ends. Otherwise, the engineer uses gained insight as input for the next iteration.

![TODO: Replace with proper graphic; Iterative Debugging Process after Layman et al. [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]: Gather context to formalize hypothesis, instrument hypothesis producing a modified system, and testing hypothesis resulting in a new iteration or a successfully proved hypothesis.](./content/debugging-process.png)

The most basic debugging technique for instrumentation and testing are manually added print statements to the source code: They generate extensive execution logs when placed  across the programs code and allow the reconstruction of the programs runtime behavior. Once the number of generated log entries increases, the required amount of work to analyze the logs gets out of hand quickly. This is why specialized debugging utilities provide tools to interact with a program at runtime: After interrupting program execution with a breakpoint, they allow engineers to inspect stack frames, inspect and modify variables, step through successive source code statements, or resume program execution eventually. These utilities work obviously best with imperative, or control-flow oriented programming languages since they interact with the debugged program on a statement and stack frame level.

Modern IDEs enable software engineers to debug programs, no matter what programming language they are implemented with, using one, generalized user interface (UI). The result is a unified user experience (UX) where the supposed correct debugger is only a click away. Software engineers have accepted these debuggers as common practice according to Alabor et al. [@Alabor_Stolze_2020]. By integrating imperative debuggers in their workflows, software engineers face a new problem when working with reactive programming (RP) though. Alabor et al. highlight that multiple of their studys participants intuitively expected their debuggers step controls to work on the RP data-flow graph and were surprised that they did not at all. This discrepancy between expected and actual behavior of the debugger lets engineers reportedly fall back to adding manual print statements.

The circumstance of debugging RP programs with the wrong debugging utilities is not new: Salvaneschi et al. described the shortcoming of traditional debuggers when confronted with RP in their paper and coined the concept of *RP Debugging* [@Salvaneschi_Mezini_2016_Inspector]. Later, Banken et al. [@Banken_Meijer_Gousios_2018] researched on a possible solution for debugging RxJS RP programs using an external visualizer sandbox named *RxFiddle*. Surprisingly, software engineers still do not have the right tools at hand today when needing them most, as Alabor et al. state.

We present a solution to this problem in this paper: With *RxJS Debugging for Visual Studio Code*, an extension for Microsoft Visual Studio Code^[https://code.visualstudio.com], engineers building RxJS applications get access to a powerful RP debugging tool. It integrates tightly with the IDE itself and requires no extra efforts to debug an RP program.

Before we do a deep-dive on the extensions functionality in Section [4](#sec:implementation), we will give an example for the main challenge of RP debugging in Section [2](#sec:challenge). We discuss related work and the process that lead to our solution in Section [3](#sec:background). Before we come to our conclusion in Section [8](#sec:conclusion), we will consider potential threats to validity in Section [6](#sec:threats_to_validity) and give an overview on potential follow-up topics, research-wise as well as practical, in Section [7](#sec:future_work).

# Expectation vs. Reality {#sec:challenge}

*Other section titles*
- *"Divergence of Reality and Expectation"*
- *"RP Debugging: Expectation vs. Reality"*
- *"Dilemma of RP Debugging"*
- *"The Wrong Tool for the Job"*
- *"The Wrong Tool at Hand"*
- *"Different Expectations"*
- *"Wrong Expectations"*

One of the main characteristics of RP is the paradigm shift away from imperatively formulated, control-flow oriented code (see Listing [1](#lst:imperative)), over to declarative, data-flow focused source code [@Salvaneschi_Mezini_2016_Inspector]. Instead of instructing the program how to do what, i.e. one step after another, we use RP abstractions to describe the transformation of a continuous flow of data as shown in Listing [2](#lst:rp).

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

Traditional debuggers reach their limitations when facing data-flow oriented code: Where we can navigate through the successive iterations of the *for* loop in Listing [1](#lst:imperative) using their step controls, this is not possible for the transformations described in Listing [2](#lst:rp): Assuming we set a breakpoint within the lambda function passed to *filter* on Line 6, stepping over to the next statement will not lead to the lambda of *map* on Line 7 as one might expect. Instead, the debugger will continue in the internal implementations of *filter*, which is part of the RxJS RP runtime environment. With a deeper understanding on what the difference between control- and data-flow oriented programing is, this might look plausible. Alabor et al. showed nonetheless that software engineers expect a different behavior from the debugging tools they have at hand [@Alabor_Stolze_2020]. As a direct consequence, engineers fall back to the archaic debugging technique of adding manual print statements, as exemplified in Listing [3](#lst:rp-print), Alabor et al. state further.

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

# Background {#sec:background}

## Related Work

The divergence of expected and actual behavior when debugging RP programs with control-flow oriented debuggers was topic for various previous research effort.



- Reactive Inspector [@Salvaneschi_Mezini_2016_Inspector]
- RxFiddle [@Banken_Meijer_Gousios_2018]
- Study by Alabor et al. [@Alabor_Stolze_2020]
  - Interviews
  - Observational Study

## Prototype and Usability Test

- Cognitive Walkthrough
	- https://github.com/swissmanu/mse-paper-pa2
- First prototype based on results by Alabor et al.
- User Journey
	- https://alabor.me/research/user-journey-debugging-of-rxjs-based-applications/
- Moderated Remote Usability Test
	- 3 Participants ... cite why this is enough regarding Nielsen
	- Outcome

# Extension {#sec:implementation}

- New work:
	- Prototyp
	  - Describe how it relates to the debugging process [@Layman_Diep_Nagappan_Singer_Deline_Venolia_2013]
	- The Result: An extension for Visual Studio Code, as described in the next section:
- Demonstrate/describe Extension
  - Log Points -> Relate with probes/traces [@McDirmid_2013]
  - Reuse same code example as in the intro

# Discussion {#sec:discussion}

- *See if necessary as distinct section or if it can be integrated within previous section instead*

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

## Research

- Verify if extension helps beginners to get started with RxJS
- Verify effectiveness of extension for professionals (re-execute previous observational study)
- More Usability Testing

# Conclusion {#sec:conclusion}

- Wrap things up
- Highlight the main contribution, again.

